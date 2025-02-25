// Universal Light Cylinder Box Tube
// Light source adjusts itself tot he object dimensions. 
// Communicates to the power system through Lamp Power Logic. 
// This module does ONLY light level management. 
// It talks to the Lamp Power Logic only with reuqests for power.

// Prim Light properties Set by Script:
// [*] on
// intensity
// radius
// falloff 
// color
// NOT set by script
// FOV 1.5
// Focus 0.0
// Ambiance 0.0
// Projector (use "spotlight projector 88")

// Rename object to something recognizable in the distribution panel listing. 
// description should be set to include any of these keywords: 
// ceiling - makes bottom surface ligt up
// interior - makes outside surface light up. Incompatible with Marker. 
// lockdown - makes inner surface turn red during lockdown
// marker - makrs outside surface red. Inconpatible with Interior. 
// source - makes it a light emitter. Use sparingly
// sensor - turns on when someone's within the radius times some fudge fatcor

// *******************************
// Constants and Globals
integer MONITOR_CHANNEL = -6546478;
integer LOCKDOWN_CHANNEL = -765489;
integer IN_LOCKDOWN = 4;

// colors
vector black = <0.0, 0.0, 0.0>;
vector gray = <0.5, 0.5, 0.5>;
vector red = <1.0, 0.0, 0.0>;
vector white = <1.0, 1.0, 1.0>;

// Settable Options
integer OPTION_DEBUG = TRUE;

// light controls
integer powerSwitch;
integer markerAsk;
integer basePowerAsk; // low-power when ceiling are off but other stuff is running
integer lightsPower;
integer lightsPowerAsk;
integer powerAsk; // what we're actually asking
integer powerAck; // received from logic
integer wasBasePowerAsk;
integer waslightsPowerAsk;

// lighting state
integer gLockdownListen = 0;
integer gTimerState; // we need this for lockdown
integer gLightState;
integer OFF = 0;
integer ON = 1;
integer HALF = 2;

// Configuration
// prim characteristics
integer FACE_TOP = 0;
list FACE_OUTER = [1];
integer FACE_LIGHT = -1;
integer FACE_BEGIN = -1;
integer FACE_END = -1;
integer FACE_INNER = -1;
vector unsliced = <0, 1, 0>;
float gRadius = 0;

// options
integer OPTION_POINT = 0;
integer OPTION_CEILING = 0;
integer OPTION_LOCKDOWN = 0;
integer OPTION_MARKER = 0; // 0 or 1 for prim only, otherwise -1
integer OPTION_INTERIOR = 0; // 0 or 1 for prim only, otherwise -1
integer OPTION_SENSOR = 0;
float SENSOR_RANGE = 0;
string CONFIGURATION = "";

string POWER_SWITCH = "PowerSwitch";
string DEBUG = "Debug";
string CEILING = "Ceiling";
string INTERIOR = "Interior";
string LOCKDOWN = "Lockdown";
string MARKER = "Marker";
string POINT = "Point"; // light source
string SENSOR = "Sensor";


// *********************************
// Debug, Moinitor, Reports
sayDebug(string message) {
    if (OPTION_DEBUG) {
        llSay(MONITOR_CHANNEL, "Light " + message);
    }
}

report_status()
{
    string status = "Universal Ceiling Lamp Status\n" + 
        "Configuration: " + CONFIGURATION + "\n" + 
        "Power Switch: " + (string)powerSwitch + "\n" + 
        "Base Power: " + (string)basePowerAsk + " watts\n" + 
        "Lights Power: " + (string)lightsPowerAsk + " watts\n" + 
        "Requesting " + (string)powerAsk + " watts\n" + 
        "Drawing " + (string)powerAck + " watts";
    llSay(MONITOR_CHANNEL, status);
}

// ************************
string LinksetDataRead(string symbol) {
    symbol = (string)llGetLinkNumber()+symbol;
    return llLinksetDataRead(symbol);
}

LinksetDataWrite(string symbol, string value) {
    symbol = (string)llGetLinkNumber()+symbol;
    llLinksetDataWrite(symbol, value);
}

string configure_cylinder(list params) {
    string configuration = "Cylinder ";
    vector scale = llGetScale();
    vector cut = llList2Vector(params, 2);
    float hollow = llList2Float(params, 3);
    gRadius = (scale.x + scale.y) / 4.0;  // mean radius
    float slicefactor = cut.y - cut.x;
    lightsPower = llFloor(PI * gRadius * gRadius * slicefactor * (1 - hollow));
    markerAsk =  llFloor(2 * PI * gRadius * scale.z * slicefactor);
    if (hollow == 0.0) {
        if (cut == unsliced) 
        {
            FACE_TOP = 0;
            FACE_OUTER = [1];
            FACE_LIGHT = 2;
            FACE_BEGIN = -1;
            FACE_END = -1;
            FACE_INNER = -1;
        } else {
            CONFIGURATION = configuration + "Sliced ";
            FACE_TOP = 0;
            FACE_OUTER = [1];
            FACE_LIGHT = 2;
            FACE_BEGIN = 3;
            FACE_END = 4;
            FACE_INNER = -1;
        }
    } 
    else 
    {
        configuration = configuration + "Hollow ";
        if (cut == unsliced) 
        {
            FACE_TOP = 0;
            FACE_OUTER = [1];
            FACE_INNER = 2;
            FACE_LIGHT = 3;
            FACE_BEGIN = -1;
            FACE_END = -1;
        } else {
            configuration = configuration + "Sliced ";
            FACE_TOP = 0;
            FACE_OUTER = [1];
            FACE_INNER = 2;
            FACE_LIGHT = 3;
            FACE_BEGIN = 4;
            FACE_END = 5;
        }
    }
    return configuration;
}

string configure_tube(list params) {
    string configuration = "Tube ";
    vector scale = llGetScale();
    vector cut = llList2Vector(params, 2);
    vector hole_size = llList2Vector(params, 5);
    float hollow = 1-2*hole_size.y;
    gRadius = (scale.y + scale.z) / 4.0;  // mean radius
    float slicefactor = cut.y - cut.x;
    lightsPower = llFloor(PI * gRadius * gRadius * slicefactor * (1 - hollow));
    markerAsk =  llFloor(2 * PI * gRadius * scale.z * slicefactor);
    if (cut == unsliced) 
    {
        FACE_TOP = 1;
        FACE_OUTER = [0]; 
        FACE_INNER = 2;
        FACE_LIGHT = 3;
        FACE_BEGIN = -1;
        FACE_END = -1;
    } 
    else // sliced
    {
        configuration = configuration + "Sliced ";
        FACE_TOP = 4;
        FACE_OUTER = [1]; 
        FACE_INNER = 3;
        FACE_LIGHT = 2;
        FACE_BEGIN = 0;
        FACE_END = 5;
    } 
    return configuration;
}

string configure_box(list params) {
    string configuration = "Box ";
    vector scale = llGetScale();
    vector cut = llList2Vector(params, 2);
    float hollow = llList2Float(params, 3);
    
    // mean radius. Yeah. That's what that is.
    // distance to side is (x+y)*0.5
    // distance to corner is (x+y)*0.7
    // Half of that is 0.6
    gRadius = (scale.x + scale.y) * 0.6; 

    // Calculating the effect of a slice is more complicated than this, 
    // But this is a good enough first approximation. 
    float slicefactor = cut.y - cut.x;
    lightsPower = llFloor(scale.x * scale.y * slicefactor * (1 - hollow));
    markerAsk =  llFloor(2 * (scale.x + scale.y) * scale.z * slicefactor);
    if (hollow == 0.0) 
    {
        FACE_TOP = 0;
        FACE_OUTER = [1, 2, 3, 4];
        FACE_INNER = -1;
        FACE_LIGHT = 5;
        FACE_BEGIN = -1;
        FACE_END = -1;
    } else {
        configuration = configuration + "Hollow ";
        FACE_TOP = 0;
        FACE_OUTER = [1, 2, 3, 4];
        FACE_INNER = 5;
        FACE_LIGHT = 6;
        FACE_BEGIN = -1;
        FACE_END = -1;
    } 
    return configuration;
}

string configure_sculpt(list params) {
    string configuration = "Unknown Sculpt ";
            
    // Sculpt/Mesh lamps cannot have marker or interior lights
    OPTION_MARKER = -1;
    OPTION_INTERIOR = -1;            
    gRadius = 5.0; // these are usually small lamps
            
    // out-of-the-box sizes for the types of lamps I have
    float magATCeiling = llVecMag(<1.20467, 1.00013, 0.29988>);
    float magATLong = llVecMag(<2.92970, 0.40000, 0.37704>);
    float magATHanging = llVecMag(<2.30000, 0.55000, 0.32500>);
    float magTPprison = llVecMag(<0.83255, 0.83255, 0.26961>);
    float magSFCSkywalk = llVecMag(<8.00, 4.73, 4.75>);
    list magnitudes = [magATCeiling, magATLong, magATHanging, magTPprison, magSFCSkywalk];
    list names = ["ATCeiling", "ATLong", "ATHanging", "TPPTison", "SFCSkywalk"];
    list faces = [1, 1, 1, 3, 4];
    list asks = [75, 100, 100, 75, 50]; //10m^2
    markerAsk = 0;
    FACE_LIGHT = 0;
    
    // find the object type by its canonical size
    // then set the parameters we need
    integer i;
    for (i= 0; i < llGetListLength(magnitudes); i = i + 1) {
        float magMe = llVecMag(llGetScale());
        if (llFabs(magMe - llList2Float(magnitudes, i)) < 0.1) {
            configuration = llList2String(names, i) + " ";
            FACE_LIGHT = llList2Integer(faces, i);
            lightsPower = llList2Integer(asks, i);
        }
    }
    return configuration;
}

string configureHardware() {
    sayDebug("configureHardware");
    // Get  the prim's basic characteristics: 
    // has it got a hollow and a slice? 
    // Then set the list of faces that we're interested in lighting. 
    list params = llGetPrimitiveParams([PRIM_TYPE]);
    integer primType = llList2Integer(params, 0);
    // clyinder and box: 
    // [ integer hole_shape, vector cut, float hollow, vector twist, vector top_size, vector top_shear ]
    // Tube: 
    // [ integer hole_shape, vector cut, float hollow, vector twist, vector hole_size, vector top_shear, 
    //  vector advanced_cut, vector taper, float revolutions, float radius_offset, float skew ]
    
    string configuration  = "";
    if (primType == PRIM_TYPE_CYLINDER) {
        configuration = configure_cylinder(params);
    } else if (primType == PRIM_TYPE_BOX) {
        configuration = configure_box(params);
    } else if (primType == PRIM_TYPE_TUBE) {
        configuration = configure_tube(params);
    } else if (primType == PRIM_TYPE_SCULPT) {
        configuration = configure_sculpt(params);
    }
    
    // store and tell logic about possibly forbidden options
    LinksetDataWrite(MARKER, (string)OPTION_MARKER);
    LinksetDataWrite(INTERIOR, (string)OPTION_INTERIOR);
    llMessageLinked(LINK_THIS, OPTION_MARKER, MARKER, llGetKey());
    llMessageLinked(LINK_THIS, OPTION_INTERIOR, INTERIOR, llGetKey());
    sayDebug("configureHardware done: " + configuration + "  lightsPower:" + (string)lightsPower + "W");
    return configuration;
}

string configureOptions() {
    sayDebug("configureOptions");
    string configuration = "";
    // Set up light options:
    // source, ceiling, lockdown, marker, interior, sensor
    powerSwitch = (integer)LinksetDataRead(POWER_SWITCH);
    OPTION_POINT = (integer)LinksetDataRead(POINT);        
    OPTION_CEILING = (integer)LinksetDataRead(CEILING);
    OPTION_LOCKDOWN = (integer)LinksetDataRead(LOCKDOWN);
    OPTION_MARKER = (integer)LinksetDataRead(MARKER);
    OPTION_INTERIOR = (integer)LinksetDataRead(INTERIOR);
    OPTION_SENSOR = (integer)LinksetDataRead(SENSOR);

    basePowerAsk = 0;

    if (OPTION_CEILING > 0) {
        configuration = configuration + CEILING + " ";
        lightsPowerAsk = lightsPower;
        if (OPTION_POINT > 0) {
            configuration = configuration + "source ";
        }
    } else {
        lightsPowerAsk = 0;
    }
        
    if (OPTION_LOCKDOWN > 0) {
        configuration = configuration + LOCKDOWN + " ";
        basePowerAsk = basePowerAsk + 2;
        gLockdownListen = llListen(LOCKDOWN_CHANNEL, "", "", "");
    }
        
    if (OPTION_MARKER > 0) {
        configuration = configuration + MARKER + " ";
        sayDebug("configureOptions OPTION_MARKER markerAsk:" + (string)markerAsk);
        basePowerAsk = basePowerAsk + markerAsk;
    } else {
        markerAsk = 0;
    }

    if (OPTION_INTERIOR > 0) {
        configuration = configuration + INTERIOR + " ";
        // *** I need to calculate this based on hollow
    }
        
    if (OPTION_SENSOR > 0) 
    {
        configuration = configuration + "sensor ";
        basePowerAsk = basePowerAsk + 5;
        SENSOR_RANGE = gRadius * 1.2;
        if (SENSOR_RANGE < 5.0) {
            SENSOR_RANGE = 5.0;
        }
        sayDebug("configureOptions SENSOR_RANGE:" + (string)SENSOR_RANGE);
    }
    sayDebug("configureOptions done");
    return configuration;
}

// ********************************
// Basic Power and Light Management
askForPower(integer onoff) {
    // calculate how much power we want
    if (onoff) {
        powerAsk = basePowerAsk + lightsPowerAsk;
    } else {
        powerAsk = basePowerAsk;
    }
    
    sayDebug("askForPower(" + (string)onoff + 
        ") powerAck:" + (string)powerAck + 
        " powerAsk:" + (string)powerAsk);

    // if it changed, ask for it
    if (powerAck != powerAsk) {
        llMessageLinked(LINK_THIS, powerAsk, "Ask", llGetKey());
    }
}

setServices(integer basePower) {
    integer onOff;
    float glow;
    vector marker;
    
    if (basePower >= basePowerAsk) {
        sayDebug("setServices has basePower");
        onOff = 1;
        glow = 0.1;
        marker = red;
    } else {
        sayDebug("setServices not enough basePower");
        onOff = 0;
        glow = 0.0;
        marker = gray;
    }

    //sayDebug("setServices OPTION_MARKER:"+(string)OPTION_MARKER);
    vector faceColor;
    integer facePower;
    float faceGlow;
    if (OPTION_MARKER > 0) {
        faceColor = marker;
        facePower = onOff;
        faceGlow = glow;
    } else {
        faceColor = white;
        facePower = OFF;
        faceGlow = 0;
    }
    integer i;
    for (i = 0; i < llGetListLength(FACE_OUTER); i++ )
    {
        integer face = llList2Integer(FACE_OUTER, i);
        llSetPrimitiveParams([PRIM_COLOR, face, faceColor, 1]);
        llSetPrimitiveParams([PRIM_FULLBRIGHT, face, facePower]);
        llSetPrimitiveParams([PRIM_GLOW, face, faceGlow]);
    }
    
    if (onOff & OPTION_SENSOR) {
        sayDebug("setLights OPTION_SENSOR:"+(string)SENSOR_RANGE);
        llSensorRepeat("", "", AGENT, SENSOR_RANGE, PI, 1);
    } else {
        llSensorRemove();
    }
}

setLights(integer mode, integer lightsPower) {
    sayDebug("setLights(mode:" + (string)mode + 
        ", lightsPower:" + (string)lightsPower + ")");

    float powerFraction = 1.0;
    if (lightsPower >= lightsPowerAsk) {
        lightsPower = lightsPowerAsk;
        powerFraction = 1; // later we can do something with this
    } else if (lightsPower > 0) {
        powerFraction = lightsPower / lightsPowerAsk;
    } else {
        powerFraction = 0;
        mode = 0;
    }
    
    float glow = 0.1 * powerFraction;
    vector color;
    
    if (mode == ON) {
        //sayDebug("setLights on powerFraction:"+(string)powerFraction);
        llPlaySound("dec4e122-f527-3004-8197-8821dc9da9ef", 1);
        color = white;
        gLightState = mode;
    } else if (mode == IN_LOCKDOWN) {
        //sayDebug("setLights lockdown powerFraction:"+(string)powerFraction);
        color = red;
        mode = 1;
    } else if (mode == 0) {
        //sayDebug("setLights Off powerFraction:"+(string)powerFraction);
        color = white;
        gLightState = mode;
    }
    
    // ceiling lights
    if (OPTION_CEILING) 
    {
        //sayDebug("setLights OPTION_CEILING");
        // ceiling lights
        llSetPrimitiveParams([PRIM_COLOR, FACE_LIGHT, color, 1]);
        llSetPrimitiveParams([PRIM_FULLBRIGHT, FACE_LIGHT, mode]);
        llSetPrimitiveParams([PRIM_GLOW, FACE_LIGHT, glow]);

        // inside face lights
        if (FACE_INNER != -1) 
        {
            //sayDebug("setLights FACE_INNER:"+(string)FACE_INNER);
            llSetPrimitiveParams([PRIM_COLOR, FACE_INNER, color, 1]);
            llSetPrimitiveParams([PRIM_FULLBRIGHT, FACE_INNER, mode]);
            llSetPrimitiveParams([PRIM_GLOW, FACE_INNER, glow]);
        }
    
        // outside face lights
        if (OPTION_INTERIOR > 0)
        {
            //sayDebug("setLights OPTION_INTERIOR");
            llSetPrimitiveParams([PRIM_COLOR, llList2Integer(FACE_OUTER, 0), color, 1]);
            llSetPrimitiveParams([PRIM_FULLBRIGHT, llList2Integer(FACE_OUTER, 0), mode]);
            llSetPrimitiveParams([PRIM_GLOW, llList2Integer(FACE_OUTER, 0), glow]);
        }
    
        // light source
        if (OPTION_POINT) 
        {
            //sayDebug("setLights OPTION_POINT");
            // [ PRIM_POINT_LIGHT, integer boolean, vector linear_color, float intensity, float radius, float falloff ]
            llSetPrimitiveParams([PRIM_POINT_LIGHT, mode, color, lightsPower, gRadius, 1.0]); 
        }
    }
}

// ********************************
// lockdown
set_lockDown() {
    sayDebug("lockDown()");
    gTimerState = IN_LOCKDOWN;
    llSetTimerEvent(30 * 60); // lockdown timeout
    setLights(IN_LOCKDOWN, powerAck);
}

end_lockdown() {
    sayDebug("end_lockdown");
    gTimerState = OFF;
    llSetTimerEvent(0);
    setLights(gLightState, powerAck);
}


default
{
    state_entry()
    {
        OPTION_DEBUG = (integer)LinksetDataRead(DEBUG);
        sayDebug("state_entry");
        CONFIGURATION = configureHardware();
        CONFIGURATION += configureOptions();
        report_status();
        if (powerSwitch) {
            askForPower(ON);
        } else {
            askForPower(OFF);
        }
        sayDebug("state_entry done");
    }
    
    touch_start(integer total_number)
        {
            integer touchedLink = llDetectedLinkNumber(0);
            integer touchedFace = llDetectedTouchFace(0);
            vector touchedUV = llDetectedTouchUV(0);
            sayDebug("touch_start Link:"+(string)touchedLink+", Face:"+(string)touchedFace);
        }

    listen(integer channel, string name, key id, string message) 
    {
        if (OPTION_LOCKDOWN & channel == LOCKDOWN_CHANNEL) 
        {
            if (message == "LOCKDOWN") {
                set_lockDown();                
            } else if (message == "RELEASE") {
                end_lockdown();
            }
        }
    }
    
    link_message(integer sender_num, integer num, string msg, key id) {
        sayDebug("link_message(" + (string)num + ", " + msg + ")");
        if (id != NULL_KEY) {
            return;
        } else if (msg == DEBUG) {
            OPTION_DEBUG = num;
        } else if (msg == "Reset") {
            llResetScript();
        } else if (msg == "Status") {
            report_status();
        } else if (msg == CEILING) {
            OPTION_CEILING = num;
            LinksetDataWrite(CEILING, (string)OPTION_CEILING);
            configureOptions();
        } else if (msg == INTERIOR) {
            OPTION_INTERIOR = num;
            if (OPTION_INTERIOR > -1) {
                LinksetDataWrite(INTERIOR, (string)OPTION_INTERIOR);
                configureOptions();
            }
        } else if (msg == MARKER) {
            OPTION_MARKER = num;
            if (OPTION_MARKER >= 0) {
                LinksetDataWrite(MARKER, (string)OPTION_MARKER);
                configureOptions();
            }
        } else if (msg == LOCKDOWN) {
            OPTION_LOCKDOWN = num;
            LinksetDataWrite(LOCKDOWN, (string)OPTION_LOCKDOWN);
            configureOptions();
        } else if (msg == POINT) {
            OPTION_POINT = num;
            LinksetDataWrite(POINT, (string)OPTION_POINT);
            configureOptions();
        } else if (msg == SENSOR) {
            OPTION_SENSOR = num;
            LinksetDataWrite(SENSOR, (string)OPTION_SENSOR);
            configureOptions();
        } else if (msg == "powerSwitch") { 
            powerSwitch = num;
            LinksetDataWrite(POWER_SWITCH, (string)powerSwitch);
            if (powerSwitch) {
                askForPower(ON);
            } else {
                askForPower(OFF);
            }
        } else if (msg == "powerAck") {
            powerAck = num;
            integer lightsPower = powerAck - basePowerAsk;
            setServices(powerAck);
            setLights(ON, lightsPower);
        } else if (msg == "Ask"){
            // ignore so it doesn't show up as error
        } else {
            sayDebug("Error: link_message did not handle message " + msg + " " + (string)num);
        }
        sayDebug("link_message done");
    }

    sensor(integer agents)
    {
        integer newLightState = OFF;
        vector mypos = llGetPos();
        for (; agents > 0; agents = agents - 1) {
            vector agentPos = llDetectedPos(agents-1);
            float deltaz = mypos.z - agentPos.z;
            if (deltaz > 0) {
                sayDebug("sensor(" + (string)agents + ")");
                newLightState = ON;
            }
        }
        if (gLightState == OFF) {
            llSensorRepeat("", "", AGENT, SENSOR_RANGE, PI, 5);
            askForPower(ON);
        }
    }
    
    no_sensor()
    {
        if (gLightState == ON) {
            llSensorRepeat("", "", AGENT, SENSOR_RANGE, PI, 1);
            askForPower(OFF);
        }
    }

    timer() 
    {
        if (OPTION_LOCKDOWN & (gTimerState == IN_LOCKDOWN)) {
            end_lockdown();
        }
    }
}
