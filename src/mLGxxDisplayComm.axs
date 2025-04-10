MODULE_NAME='mLGxxDisplayComm'  (
                                    dev vdvObject,
                                    dev vdvCommObjects[],
                                    dev dvPort
                                )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.TimelineUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT
constant long TL_IP_CHECK = 1
constant long TL_QUEUE_FAILED_RESPONSE    = 2
constant long TL_HEARTBEAT    = 3

constant long TL_HEARTBEAT_INTERVAL[] = { 30000 }
constant long TL_IP_CHECK_INTERVAL[] = { 3000 }
constant long TL_QUEUE_FAILED_RESPONSE_INTERVAL[]    = { 500 }

constant integer MAX_QUEUE_COMMANDS = 50
constant integer MAX_QUEUE_STATUS = 200
constant integer MAX_OBJECTS    = 255

constant integer TELNET_WILL    = $FB
constant integer TELNET_DO    = $FD
constant integer TELNET_DONT    = $FE
constant integer TELNET_WONT    = $FC

constant integer COMM_MODE_ONE_WAY    = 1
constant integer COMM_MODE_TWO_WAY    = 2


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE
struct _Object {
    char iInitialized
    char iRegistered
}

struct _Queue {
    char iBusy
    char iHasItems
    integer iCommandHead
    integer iCommandTail
    integer iStatusHead
    integer iStatusTail
    integer iStrikeCount
    char iResendLast
    char cLastMess[NAV_MAX_BUFFER]
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _Object uObject[MAX_OBJECTS]

volatile _Queue uQueue
volatile char cCommandQueue[MAX_QUEUE_COMMANDS][NAV_MAX_BUFFER]
volatile char cStatusQueue[MAX_QUEUE_STATUS][NAV_MAX_BUFFER]

volatile char cRxBuffer[NAV_MAX_BUFFER]
volatile char iSemaphore

volatile integer iCommMode = COMM_MODE_TWO_WAY    //Default Two-Way

volatile char cIPAddress[15]
volatile integer iIPConnected = false
volatile char iIPAuthenticated

volatile char iInitializing
volatile integer iInitializingObjectID

volatile char iInitialized
volatile char iCommunicating

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function SendStringRaw(char cString[]) {
    send_string dvPort,"cString"
}


define_function SendString(char cString[]) {
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Formatting String'")
    SendStringRaw("cString,NAV_CR")
}


define_function AddToQueue(char cString[], integer iPriority) {
    stack_var integer iQueueWasEmpty
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Adding to Queue'")

    iQueueWasEmpty = (!uQueue.iHasItems && !uQueue.iBusy)

    switch (iPriority) {
        case true: {    //Commands have priority over status requests
            select {
                active (uQueue.iCommandHead == max_length_array(cCommandQueue)): {
                    if (uQueue.iCommandTail != 1) {
                        uQueue.iCommandHead = 1
                        cCommandQueue[uQueue.iCommandHead] = cString
                        uQueue.iHasItems = true
                    }
                }
                active (uQueue.iCommandTail != (uQueue.iCommandHead + 1)): {
                    uQueue.iCommandHead++
                    cCommandQueue[uQueue.iCommandHead] = cString
                    uQueue.iHasItems = true
                }
            }
        }
        case false: {
            select {
                active (uQueue.iStatusHead == max_length_array(cStatusQueue)): {
                    if (uQueue.iStatusTail != 1) {
                        uQueue.iStatusHead = 1
                        cStatusQueue[uQueue.iStatusHead] = cString
                        uQueue.iHasItems = true
                    }
                }
                active (uQueue.iStatusTail != (uQueue.iStatusHead + 1)): {
                    uQueue.iStatusHead++
                    cStatusQueue[uQueue.iStatusHead] = cString
                    uQueue.iHasItems = true
                }
            }
        }
    }

    if (iQueueWasEmpty) { SendNextQueueItem(); }
}


define_function char[NAV_MAX_BUFFER] RemoveFromQueue() {
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Removing from Queue'")
    if (uQueue.iHasItems && !uQueue.iBusy) {
        uQueue.iBusy = true
        select {
            active (uQueue.iCommandHead != uQueue.iCommandTail): {
                if (uQueue.iCommandTail == max_length_array(cCommandQueue)) {
                    uQueue.iCommandTail = 1
                }
                else {
                    uQueue.iCommandTail++
                }

                uQueue.cLastMess = cCommandQueue[uQueue.iCommandTail]
            }
            active (uQueue.iStatusHead != uQueue.iStatusTail): {
                if (uQueue.iStatusTail == max_length_array(cStatusQueue)) {
                    uQueue.iStatusTail = 1
                }
                else {
                    uQueue.iStatusTail++
                }

                uQueue.cLastMess = cStatusQueue[uQueue.iStatusTail]
            }
        }

        if ((uQueue.iCommandHead == uQueue.iCommandTail) && (uQueue.iStatusHead == uQueue.iStatusTail)) {
            uQueue.iHasItems = false
        }

        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Last Mess: ',uQueue.cLastMess")
        return GetMess(uQueue.cLastMess)
    }

    return ''
}


define_function integer GetMessID(char cParam[]) {
    return atoi(NAVGetStringBetween(cParam,'<','|'))
}


define_function integer GetSubscriptionMessID(char cParam[]) {
    return atoi(NAVGetStringBetween(cParam,'[','*'))
}


define_function char[NAV_MAX_BUFFER] GetMess(char cParam[]) {
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Got Mess: ',NAVGetStringBetween(cParam,'|','>')")
    return NAVGetStringBetween(cParam,'|','>')
}


define_function InitializeObjects() {
    stack_var integer x

    if (!iInitializing) {
        for (x = 1; x <= length_array(vdvCommObjects); x++) {
            if (uObject[x].iRegistered && !uObject[x].iInitialized) {
                iInitializing = true
                send_string vdvCommObjects[x],"'INIT<',itoa(x),'>'"
                iInitializingObjectID = x
                break
                }

            if (x == length_array(vdvCommObjects) && !iInitializing) {
                iInitializingObjectID = x
                iInitialized = true
                UpdateFeedback()
            }
        }
    }
}


define_function GoodResponse() {
    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Good Response'")
    uQueue.iBusy = false
    NAVTimelineStop(TL_QUEUE_FAILED_RESPONSE)

    uQueue.iStrikeCount = 0
    uQueue.iResendLast = false
    SendNextQueueItem()
}


define_function SendNextQueueItem() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Sending Next'")
    if (uQueue.iResendLast) {
        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Resending Last'")
        uQueue.iResendLast = false
        cTemp = GetMess(uQueue.cLastMess)
    }else {
        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Requesting from queue'")
        cTemp= RemoveFromQueue()
    }

    if (length_array(cTemp)) {
        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Requesting to send'")
        SendString(cTemp)

        switch (iCommMode) {
            case COMM_MODE_TWO_WAY: {
                NAVTimelineStart(TL_QUEUE_FAILED_RESPONSE,
                                    TL_QUEUE_FAILED_RESPONSE_INTERVAL,
                                    TIMELINE_ABSOLUTE,
                                    TIMELINE_ONCE)
            }
            case COMM_MODE_ONE_WAY: {
                wait 5 GoodResponse()        //Move on if in one way mode
            }
        }
    }
}

define_event timeline_event[TL_QUEUE_FAILED_RESPONSE] {
    if (uQueue.iBusy) {
        if (uQueue.iStrikeCount < 3) {
            uQueue.iStrikeCount++
            uQueue.iResendLast = true
            SendNextQueueItem()
        }
        else {
            iCommunicating = false
            Reset()
        }
    }
}


define_function Reset() {
    ReInitializeObjects()
    InitializeQueue()
}


define_function ReInitializeObjects() {
    stack_var integer x

    iInitializing = false
    iInitialized = false
    iInitializingObjectID = 1

    UpdateFeedback()

    for (x = 1; x <= MAX_OBJECTS; x++) {
        uObject[x].iInitialized = false
    }
}


define_function InitializeQueue() {
    uQueue.iBusy = false
    uQueue.iHasItems = false
    uQueue.iCommandHead = 1
    uQueue.iCommandTail = 1
    uQueue.iStatusHead = 1
    uQueue.iStatusTail = 1
    uQueue.iStrikeCount = 0
    uQueue.iResendLast = false
    uQueue.cLastMess = "''"
}


define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]

    iSemaphore = true

    while (length_array(cRxBuffer) && (NAVContains(cRxBuffer,'x')
            || NAVContains(cRxBuffer, "'x', NAV_CR, NAV_LF"))) {
        cTemp = remove_string(cRxBuffer,"'x',NAV_CR,NAV_LF",1)

        if (!length_array(cTemp)) {
            cTemp = remove_string(cRxBuffer,"'x'",1)
        }

        if (length_array(cTemp)) {
            stack_var integer iResponseMessID
            stack_var integer iStripLength

            iStripLength = length_array(cTemp) - find_string(cTemp, "'x'", 1) + 1

            cTemp = NAVStripCharsFromRight(cTemp, iStripLength)    //Remove x,CR,LF

            select {
                active (NAVContains(uQueue.cLastMess,'HEARTBEAT')): {
                    iCommunicating = true
                    if (iCommunicating && !iInitialized) {
                        InitializeObjects()
                    }

                    GoodResponse()
                }
                active (1): {
                    iResponseMessID = GetMessID(uQueue.cLastMess)
                    if (iResponseMessID && (iResponseMessID <= length_array(vdvCommObjects))) {
                        send_string vdvCommObjects[iResponseMessID],"'RESPONSE_MSG<',GetMess(uQueue.cLastMess),'|',cTemp,'>'"
                    }
                }
            }
        }
    }

    iSemaphore = false
}


define_function MaintainIPConnection() {
    if (!iIPConnected) {
        NAVClientSocketOpen(dvPort.port,cIPAddress,9761,IP_TCP)
    }
}


define_function UpdateFeedback() {
    [vdvObject,NAV_IP_CONNECTED]    = (iIPConnected && iIPAuthenticated)
    if (iCommMode == COMM_MODE_TWO_WAY) [vdvObject,DEVICE_COMMUNICATING] = (iCommunicating)
    [vdvObject,DATA_INITIALIZED] = (iInitialized)
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort,cRxBuffer
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            send_command data.device,"'SET MODE DATA'"
            send_command data.device,"'SET BAUD 9600,N,8,1 485 DISABLE'"
            send_command data.device,"'B9MOFF'"
            send_command data.device,"'CHARD-0'"
            send_command data.device,"'CHARDM-0'"
            send_command data.device,"'HSOFF'"
        }

        if (iCommMode == COMM_MODE_TWO_WAY) {// && data.device.number == 0) {
            NAVTimelineStart(TL_HEARTBEAT,TL_HEARTBEAT_INTERVAL,TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
        }

        if (data.device.number == 0) { iIPConnected = true }

        UpdateFeedback()
    }
    string: {
        select {
            active (NAVStartsWith(cRxBuffer,"$FF")): {
                stack_var char cTemp[3]
                cTemp = get_buffer_string(cRxBuffer,length_array(cRxBuffer))
                switch (cTemp[2]) {
                    case TELNET_WILL: { send_string data.device,"cTemp[1],TELNET_DONT,cTemp[3]" }
                    case TELNET_DO: { send_string data.device,"cTemp[1],TELNET_WONT,cTemp[3]" }
                }
            }
            active (1): {
                if (!iSemaphore && iCommMode == COMM_MODE_TWO_WAY) { Process() }
            }
        }
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(dvPort.port)
            iIPConnected = false
            iIPAuthenticated = false
            UpdateFeedback()
        }
    }
    onerror: {
        if (data.device.number == 0) {
            iIPConnected = false
            iIPAuthenticated = false
            UpdateFeedback()
        }
    }
}

data_event[vdvObject] {
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[2][NAV_MAX_CHARS]

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'PROPERTY': {
                switch (cCmdParam[1]) {
                    case 'IP_ADDRESS': {
                        cIPAddress = cCmdParam[2]
                        NAVTimelineStart(TL_IP_CHECK,TL_IP_CHECK_INTERVAL,timeline_absolute,timeline_repeat)
                    }
                    case 'COMM_MODE': {
                        switch (cCmdParam[2]) {
                            case 'ONE-WAY': { //One-Way
                                iCommMode = COMM_MODE_ONE_WAY
                                NAVTimelineStop(TL_HEARTBEAT)
                            }
                            case 'TWO-WAY': { //Two-Way
                                iCommMode = COMM_MODE_TWO_WAY
                                if (!timeline_active(TL_HEARTBEAT)) {
                                    NAVTimelineStart(TL_HEARTBEAT,TL_HEARTBEAT_INTERVAL,TIMELINE_ABSOLUTE,TIMELINE_REPEAT)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


data_event[vdvCommObjects] {
    online: {
        send_string data.device,"'REGISTER<',itoa(get_last(vdvCommObjects)),'>'"
    }
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var integer iResponseObjectMessID

        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
        cCmdHeader = DuetParseCmdHeader(data.text)

        switch (cCmdHeader) {
            case 'COMMAND_MSG': {
                // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_ADDING_COMMAND_TO_QUEUE',data.text")
                AddToQueue("cCmdHeader,data.text",true)
            }
            case 'POLL_MSG': {
                if (iCommMode == COMM_MODE_TWO_WAY) {    //Only allow if running two-way mode
                    AddToQueue("cCmdHeader,data.text",false)
                }
            }
            case 'RESPONSE_OK': {
                if (NAVGetStringBetween(data.text,'<','>') == NAVGetStringBetween(uQueue.cLastMess,'<','>')) {
                    GoodResponse()
                }
            }
            case 'INIT_DONE': {
                iInitializing = false
                iResponseObjectMessID = atoi(NAVGetStringBetween(data.text,'<','>'))
                uObject[get_last(vdvCommObjects)].iInitialized = true
                InitializeObjects()
                if (get_last(vdvCommObjects) == length_array(vdvCommObjects)) {
                    send_string vdvObject,"'INIT_DONE'"
                    send_string vdvCommObjects,"'START_POLLING!='"
                }
            }
            case 'REGISTER': {
                iResponseObjectMessID = atoi(NAVGetStringBetween(data.text,'<','>'))
                uObject[get_last(vdvCommObjects)].iRegistered = true

                //Start init process if one-way
                if (get_last(vdvCommObjects) == length_array(vdvCommObjects) && (iCommMode == COMM_MODE_ONE_WAY) && !iInitialized) {
                    InitializeObjects()
                }
            }
        }
    }
}


timeline_event[TL_HEARTBEAT] {
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_HEARTBEAT_TIMELINE'")
    if (!uQueue.iHasItems && !uQueue.iBusy && (iCommMode == COMM_MODE_TWO_WAY)) {    //Make sure we are in two-way mode
        AddToQueue("'POLL_MSG<HEARTBEAT|ka 01 FF>'",false)
        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_HEARTBEAT_TIMELINE_CONDITION_MET'")
    }
}


timeline_event[TL_IP_CHECK] { MaintainIPConnection() }


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
