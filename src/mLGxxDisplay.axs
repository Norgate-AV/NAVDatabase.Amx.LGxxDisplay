MODULE_NAME='mLGxxDisplay'      (
                                    dev vdvObject,
                                    dev dvPort
                                )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_STRING_GATHER_CALLBACK
#DEFINE USING_NAV_LOGIC_ENGINE_EVENT_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.LogicEngine.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.StringUtils.axi'
#include 'NAVFoundation.TimelineUtils.axi'
#include 'LibLGxxDisplay.axi'

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

constant long TL_SOCKET_CHECK           = 1

constant integer REQUIRED_POWER_ON      = 1
constant integer REQUIRED_POWER_OFF     = 2

constant integer ACTUAL_POWER_ON        = 1
constant integer ACTUAL_POWER_OFF       = 2

constant integer INPUT_VGA_1            = 1
constant integer INPUT_DVI_1            = 2
constant integer INPUT_VIDEO_1          = 3
constant integer INPUT_SVIDEO_1         = 4
constant integer INPUT_COMPONENT_1      = 5
constant integer INPUT_OPTION_1         = 6
constant integer INPUT_DISPLAYPORT_1    = 7
constant integer INPUT_DISPLAYPORT_2    = 8
constant integer INPUT_HDMI_1           = 9
constant integer INPUT_HDMI_2           = 10
constant integer INPUT_HDMI_3           = 11
constant integer INPUT_HDBASE_T_1       = 12

constant char INPUT_SNAPI_PARAMS[][NAV_MAX_CHARS]   =   {
                                                            'VGA,1',
                                                            'DVI,1',
                                                            'COMPOSITE,1',
                                                            'S-VIDEO,1',
                                                            'OPTION,1',
                                                            'COMPONENT,1',
                                                            'DISPLAYPORT,1',
                                                            'DISPLAYPORT,2',
                                                            'HDMI,1',
                                                            'HDMI,2',
                                                            'HDMI,3',
                                                            'HDBASE_T,1'
                                                        }

constant char INPUT_COMMANDS[][NAV_MAX_CHARS]   =   {
                                                        '60',
                                                        '70',
                                                        '20',
                                                        '21',
                                                        '40',
                                                        '98',
                                                        'C0',
                                                        'C1',
                                                        '90',
                                                        '91',
                                                        'C2',
                                                        'C3'
                                                    }

constant integer AUDIO_MUTE_ON        = 1
constant integer AUDIO_MUTE_OFF       = 2

constant integer GET_POWER          = 1
constant integer GET_INPUT          = 2
constant integer GET_AUDIO_MUTE     = 3
constant integer GET_VOLUME         = 4

constant integer COMM_MODE_ONE_WAY       = 1
constant integer COMM_MODE_TWO_WAY       = 2
constant integer COMM_MODE_ONE_WAY_BASIC = 3

constant integer MODE_SERIAL       = 1
constant integer MODE_IP_DIRECT    = 2
constant integer MODE_IP_INDIRECT  = 3


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile _NAVDisplay object

volatile long socketCheck[] = { 3000 }

volatile char id[2] = '01'

volatile integer mode = MODE_SERIAL
volatile integer serialMode = COMM_MODE_TWO_WAY

volatile integer pollSequence = GET_POWER


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

define_function SendString(char payload[]) {
    send_string dvPort, "payload, NAV_CR"
}





define_function GetInitialized() {
    SendQuery(GET_POWER)
    SendQuery(GET_INPUT)
   // SendQuery(GET_MUTE)
   // SendQuery(GET_VOLUME)
}


define_function SendQuery(integer query) {
    switch (query) {
        case GET_POWER: { SendString(BuildProtocol('ka', id, '')) }
        case GET_INPUT: { SendString(BuildProtocol('xb', id, '')) }
        default:        { SendQuery(GET_POWER) }
    }
}


define_function CommunicationTimeOut(integer timeout) {
    cancel_wait 'TimeOut'

    module.Device.IsCommunicating = true
    UpdateFeedback()

    wait (timeout * 10) 'TimeOut' {
        module.Device.IsCommunicating = false
        UpdateFeedback()
    }
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    module.Device.IsCommunicating = false
    module.Device.IsInitialized = false
    UpdateFeedback()

    NAVLogicEngineStop()
}


define_function SetPower(integer state) {
    switch (state) {
        case REQUIRED_POWER_ON:  { SendString(BuildProtocol('ka', id, '1')) }
        case REQUIRED_POWER_OFF: { SendString(BuildProtocol('ka', id, '0')) }
    }
}


define_function SetInput(integer input) {
    SendString(BuildProtocol('xb', id, INPUT_COMMANDS[input]))
}


define_function SetVolume(sinteger level) {
    SendString(BuildProtocol('kf', id, format('%02X', level)))
}


define_function SetMute(char state) {
    SendString(BuildProtocol('ke', id, format('%02d', !state)))

    switch (state) {
        case REQUIRED_POWER_ON:  { SendString(BuildProtocol('ke', id, '1')) }
        case REQUIRED_POWER_OFF: { SendString(BuildProtocol('ke', id, '0')) }
    }
}


define_function integer ModeIsIp(integer mode) {
    return mode == MODE_IP_DIRECT || mode == MODE_IP_INDIRECT
}


define_function MaintainSocketConnection() {
    if (module.Device.SocketConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT,
                        module.Device.SocketConnection.Address,
                        module.Device.SocketConnection.Port,
                        IP_TCP)
}


#IF_DEFINED USING_NAV_LOGIC_ENGINE_EVENT_CALLBACK
define_function NAVLogicEngineEventCallback(_NAVLogicEngineEvent args) {
    if (!module.Device.SocketConnection.IsConnected && ModeIsIp(mode)) {
        return;
    }

    switch (args.Name) {
        case NAV_LOGIC_ENGINE_EVENT_QUERY: {
            SendQuery(pollSequence)
            return
        }
        case NAV_LOGIC_ENGINE_EVENT_ACTION: {
            if (module.CommandBusy) {
                return
            }

            if (object.PowerState.Required && (object.PowerState.Required == object.PowerState.Actual)) { object.PowerState.Required = 0; return }
            if (object.Input.Required && (object.Input.Required == object.Input.Actual)) { object.Input.Required = 0; return }

            if (object.PowerState.Required && (object.PowerState.Required != object.PowerState.Actual)) {
                SetPower(object.PowerState.Required)
                module.CommandBusy = true
                wait 50 module.CommandBusy = false
                pollSequence = GET_POWER
                return
            }

            if (object.Input.Required && (object.PowerState.Actual == ACTUAL_POWER_ON) && (object.Input.Required != object.Input.Actual)) {
                SetInput(object.Input.Required)
                module.CommandBusy = true
                wait 20 module.CommandBusy = false
                pollSequence = GET_INPUT
                return
            }
        }
    }
}
#END_IF


// define_function Drive() {
//     iLoop++

//     switch (iLoop) {
//         case 1:
//         case 6:
//         case 11:
//         case 16: {
//             if (iCommMode == COMM_MODE_TWO_WAY) {
//                 SendQuery(pollSequence)
//                 return
//             }
//         }
//         case 21: { iLoop = 0; return }
//         default: {
//             switch (iCommMode) {
//                 case COMM_MODE_ONE_WAY:
//                 case COMM_MODE_TWO_WAY: {
//                     if (iCommandLockOut) { return }
//                     if (uDisplay.PowerState.Required && (uDisplay.PowerState.Required == uDisplay.PowerState.Actual)) { uDisplay.PowerState.Required = 0; return }
//                     if (uDisplay.Input.Required && (uDisplay.Input.Required == uDisplay.Input.Actual)) { uDisplay.Input.Required = 0; return }
//                     if (uDisplay.Volume.Level.Required >= 0 && (uDisplay.Volume.Level.Required == uDisplay.Volume.Level.Actual)) { uDisplay.Volume.Level.Required = -1; return }

//                     if (uDisplay.PowerState.Required && (uDisplay.PowerState.Required != uDisplay.PowerState.Actual) && module.Device.IsCommunicating) {
//                         SetPower(uDisplay.PowerState.Required)
//                         iCommandLockOut = true
//                         switch (iCommMode) {
//                             case COMM_MODE_ONE_WAY: { //One-Way
//                                 switch (uDisplay.PowerState.Required) {
//                                     case POWER_ON: {
//                                         wait 80 {
//                                             iCommandLockOut = false
//                                         }
//                                     }
//                                     case REQUIRED_POWER_OFF: {
//                                         wait 20 {
//                                             iCommandLockOut = false
//                                         }
//                                     }
//                                 }

//                                 uDisplay.PowerState.Actual = uDisplay.PowerState.Required    //Emulate
//                             }
//                             case COMM_MODE_TWO_WAY: {
//                                 wait 20 iCommandLockOut = false
//                             }
//                         }

//                         pollSequence = GET_POWER
//                         return
//                     }

//                     if (uDisplay.Input.Required && (uDisplay.Input.Required  != uDisplay.Input.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
//                         SetInput(uDisplay.Input.Required)
//                         if (iCommMode == COMM_MODE_ONE_WAY) {    //One-Way
//                             uDisplay.Input.Actual = uDisplay.Input.Required    //Emulate
//                         }

//                         iCommandLockOut = true
//                         wait 20 iCommandLockOut = false
//                         pollSequence = GET_INPUT
//                         return
//                     }

//                     if ([vdvObject,VOL_UP] && uDisplay.PowerState.Actual == ACTUAL_POWER_ON) { uDisplay.Volume.Level.Required++ }
//                     if ([vdvObject,VOL_DN] && uDisplay.PowerState.Actual == ACTUAL_POWER_ON) { uDisplay.Volume.Level.Required-- }

//                     if (uDisplay.Volume.Level.Required && (uDisplay.Volume.Level.Required != uDisplay.Volume.Level.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
//                         SetVolume(uDisplay.Volume.Level.Required)
//                         iCommandLockOut = true
//                         wait 5 iCommandLockOut = false
//                         pollSequence = GET_VOLUME
//                         return
//                     }
//                 }
//                 case COMM_MODE_ONE_WAY_BASIC: {
//                     if (uDisplay.PowerState.Required) { SetPower(uDisplay.PowerState.Required); uDisplay.PowerState.Required = 0; NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'LG_SENDING_POWER_COMMAND_TO_COMM') }
//                     if (uDisplay.Input.Required) { SetInput(uDisplay.Input.Required); uDisplay.Input.Required = 0; NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'LG_SENDING_INPUT_COMMAND_TO_COMM') }
//                 }
//             }
//         }
//     }
// }


#IF_DEFINED USING_NAV_STRING_GATHER_CALLBACK
define_function NAVStringGatherCallback(_NAVStringGatherResult args) {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char delimiter[NAV_MAX_CHARS]

    stack_var char cmd[1]
    stack_var char thisId[2]

    data = args.Data
    delimiter = args.Delimiter

    if (ModeIsIp(mode)) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                                dvPort,
                                                data))
    }

    data = NAVStripRight(data, length_array(delimiter))

    cmd = NAVStripRight(remove_string(data,' ', 1), 1)
    thisId = NAVStripRight(remove_string(data,' ', 1), 1)

    if (thisId != id) {
        return
    }

    remove_string(data, 'OK', 1)

    switch (lower_string(cmd)) {
        case 'a': {
            switch (data) {
                case '00': { object.PowerState.Actual = ACTUAL_POWER_OFF }
                case '01': { object.PowerState.Actual = ACTUAL_POWER_ON }
            }


            if (!module.Device.IsInitialized) {
                module.Device.IsInitialized = true
            }

            UpdateFeedback()
        }
        case 'b': {
            object.Input.Actual = NAVFindInArrayString(INPUT_SNAPI_PARAMS, data)

            UpdateFeedback()
            pollSequence = GET_POWER
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    switch (event.Name) {
        case NAV_MODULE_PROPERTY_EVENT_IP_ADDRESS: {
            module.Device.SocketConnection.Address = NAVTrimString(event.Args[1])
            NAVTimelineStart(TL_SOCKET_CHECK, socketCheck, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
        }
        case NAV_MODULE_PROPERTY_EVENT_PORT: {
            module.Device.SocketConnection.Port = atoi(event.Args[1])
        }
        case 'COMM_MODE': {
            switch (event.Args[1]) {
                case 'SERIAL': {
                    mode = MODE_SERIAL
                }
                case 'IP_DIRECT': {
                    mode = MODE_IP_DIRECT
                }
                case 'IP_INDIRECT': {
                    mode = MODE_IP_INDIRECT
                }
            }
        }
        case NAV_MODULE_PROPERTY_EVENT_ID: {
            id = format('%02d', atoi(event.Args[1]))
        }

        case 'UNIT_ID': {
            id = format('%02d', atoi(event.Args[1]))
        }
        case 'SERIAL_MODE': {
            switch (event.Args[1]) {
                case 'ONE_WAY': {
                    switch (event.Args[2]) {
                        case 'BASIC': { serialMode = COMM_MODE_ONE_WAY_BASIC }
                        case 'ADVANCED': { serialMode = COMM_MODE_ONE_WAY }
                    }

                    module.Device.IsCommunicating = true
                }
                case 'TWO_WAY': {
                    serialMode = COMM_MODE_TWO_WAY
                }
            }
        }
    }
}
#END_IF


#IF_DEFINED USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    SendString(event.Payload)
}
#END_IF


define_function HandleSnapiMessage(_NAVSnapiMessage message, tdata data) {
    switch (message.Header) {
        case 'POWER': {
            switch (message.Parameter[1]) {
                case 'ON': {
                    object.PowerState.Required = REQUIRED_POWER_ON
                }
                case 'OFF': {
                    object.PowerState.Required = REQUIRED_POWER_OFF
                    object.Input.Required = 0
                }
            }
        }
        // case 'MUTE': {
        //     if (object.PowerState.Actual != ACTUAL_POWER_ON) {
        //         return
        //     }

        //     switch (message.Parameter[1]) {
        //         case 'ON': {
        //             object.VideoMute.Required = VIDEO_MUTE_ON
        //         }
        //         case 'OFF': {
        //             object.VideoMute.Required = VIDEO_MUTE_OFF
        //         }
        //     }
        // }
        case 'VOLUME': {
            switch (message.Parameter[1]) {
                case 'ABS': {
                    SetVolume(atoi(message.Parameter[2]))
                    pollSequence = GET_VOLUME
                }
                default: {
                    SetVolume(atoi(message.Parameter[1]) * 63 / 255)
                    pollSequence = GET_VOLUME
                }
            }
        }
        case 'INPUT': {
            stack_var integer input
            stack_var char inputCommand[NAV_MAX_CHARS]

            NAVTrimStringArray(message.Parameter)
            inputCommand = NAVArrayJoinString(message.Parameter, ',')

            input = NAVFindInArrayString(INPUT_SNAPI_PARAMS, inputCommand)

            if (input <= 0) {
                NAVErrorLog(NAV_LOG_LEVEL_WARNING,
                            "'mLGxxDisplay => Invalid input: ', inputCommand")

                return
            }

            object.PowerState.Required = REQUIRED_POWER_ON
            object.Input.Required = input
        }
    }
}


define_function UpdateFeedback() {
    if (serialMode != COMM_MODE_TWO_WAY) {
        return
    }

    [vdvObject, POWER_FB]    = (object.PowerState.Actual == ACTUAL_POWER_ON)
    [vdvObject, DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject, DATA_INITIALIZED] = (module.Device.IsInitialized)
    [vdvObject, VOL_MUTE_FB]    = (object.Volume.Mute.Actual == AUDIO_MUTE_ON)
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, module.RxBuffer.Data
    module.Device.SocketConnection.Socket = dvPort.PORT
    module.Device.SocketConnection.Port = DEFAULT_IP_PORT
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            NAVCommand(data.device, "'SET BAUD 9600,N,8,1 485 DISABLE'")
            NAVCommand(data.device, "'B9MOFF'")
            NAVCommand(data.device, "'CHARD-0'")
            NAVCommand(data.device, "'CHARDM-0'")
            NAVCommand(data.device, "'HSOFF'")
        }

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = true
            UpdateFeedback()
        }

        NAVLogicEngineStart()
    }
    string: {
        CommunicationTimeOut(30)

        if (data.device.number == 0) {
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                    data.device,
                                                    data.text))
        }

        select {
            active(NAVContains(module.RxBuffer.Data, "'x', NAV_CR, NAV_LF")): {
                NAVStringGather(module.RxBuffer, "'x', NAV_CR, NAV_LF")
            }
            active(true): {
                NAVStringGather(module.RxBuffer, 'x')
            }
        }
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(data.device.port)
            Reset()
        }
    }
    onerror: {
        if (data.device.number == 0) {
            Reset()
        }

        NAVErrorLog(NAV_LOG_LEVEL_ERROR,
                    "'mLGxxDisplay => OnError: ', NAVGetSocketError(type_cast(data.number))")
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Monitor'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.lg.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,LG'")
    }
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        HandleSnapiMessage(message, data)
    }
}


// data_event[vdvObject] {
//     command: {
//         stack_var char cCmdHeader[NAV_MAX_CHARS]
//         stack_var char cCmdParam[3][NAV_MAX_CHARS]

//         NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Command from ',NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'),': [',data.text,']'")

//         cCmdHeader = DuetParseCmdHeader(data.text)
//         cCmdParam[1] = DuetParseCmdParam(data.text)
//         cCmdParam[2] = DuetParseCmdParam(data.text)
//         cCmdParam[3] = DuetParseCmdParam(data.text)

//         switch (cCmdHeader) {
//             case 'PROPERTY': {
//                 switch (cCmdParam[1]) {

//                 }
//             }
//             case 'ADJUST': {}
//             case 'POWER': {
//                 switch (cCmdParam[1]) {
//                     case 'ON': {
//                         uDisplay.PowerState.Required = POWER_ON
//                         Drive()
//                     }
//                     case 'OFF': {
//                         uDisplay.PowerState.Required = REQUIRED_POWER_OFF
//                         uDisplay.Input.Required = 0
//                         Drive()
//                     }
//                 }
//             }
//             case 'INPUT': {
//                 switch (cCmdParam[1]) {
//                     case 'VGA': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_VGA_1
//                                 Drive()
//                             }
//                         }
//                     }
//                     case 'DVI': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_DVI_1
//                                 Drive()
//                             }
//                         }
//                     }
//                     case 'COMPOSITE': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_VIDEO_1
//                                 Drive()
//                             }
//                         }
//                     }
//                     case 'S-VIDEO': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_SVIDEO_1
//                                 Drive()
//                             }
//                         }
//                     }
//                     case 'COMPONENT': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_RGB_1
//                                 Drive()
//                             }
//                         }
//                     }
//                     case 'DISPLAYPORT': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_DISPLAYPORT_1
//                                 Drive()
//                             }
//                             case '2': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_DISPLAYPORT_2
//                                 Drive()
//                             }
//                         }
//                     }
//                     case 'HDMI': {
//                         switch (cCmdParam[2]) {
//                             case '1': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_HDMI_1
//                                 Drive()
//                             }
//                             case '2': {
//                                 if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
//                                     uDisplay.PowerState.Required = POWER_ON
//                                 }

//                                 uDisplay.Input.Required = REQUIRED_INPUT_HDMI_2
//                                 Drive()
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
// }


channel_event[vdvObject, 0] {
    on: {
        switch (channel.channel) {
            case PWR_ON: {
                object.PowerState.Required = REQUIRED_POWER_ON
            }
            case PWR_OFF: {
                object.PowerState.Required = REQUIRED_POWER_OFF
                object.Input.Required = 0
            }
        }
    }
}


timeline_event[TL_SOCKET_CHECK] {
    MaintainSocketConnection()
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
