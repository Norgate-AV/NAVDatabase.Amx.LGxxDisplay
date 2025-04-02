MODULE_NAME='mLGxxDisplay'      (
                                    dev vdvObject,
                                    dev vdvCommObject
                                )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
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

constant long TL_DRIVE = 1

constant long TL_DRIVE_INTERVAL[] = { 200 }

constant integer REQUIRED_POWER_ON    = 1
constant integer REQUIRED_POWER_OFF    = 2

constant integer ACTUAL_POWER_ON    = 1
constant integer ACTUAL_POWER_OFF    = 2

constant integer REQUIRED_INPUT_VGA_1    = 1
constant integer REQUIRED_INPUT_RGB_1    = 2
constant integer REQUIRED_INPUT_DVI_1    = 3
constant integer REQUIRED_INPUT_VIDEO_1    = 4
constant integer REQUIRED_INPUT_VIDEO_2    = 5
constant integer REQUIRED_INPUT_SVIDEO_1    = 6
constant integer REQUIRED_INPUT_TV_1    = 7
constant integer REQUIRED_INPUT_COMPONENT_1    = 8
constant integer REQUIRED_INPUT_OPTION_1    = 9
constant integer REQUIRED_INPUT_COMPONENT_2    = 10
constant integer REQUIRED_INPUT_DISPLAYPORT_1    = 11
constant integer REQUIRED_INPUT_HDMI_1    = 12
constant integer REQUIRED_INPUT_HDMI_2    = 13
constant integer REQUIRED_INPUT_DISPLAYPORT_2    = 14

constant integer ACTUAL_INPUT_VGA_1    = 1
constant integer ACTUAL_INPUT_RGB_1    = 2
constant integer ACTUAL_INPUT_DVI_1    = 3
constant integer ACTUAL_INPUT_VIDEO_1    = 4
constant integer ACTUAL_INPUT_VIDEO_2    = 5
constant integer ACTUAL_INPUT_SVIDEO_1    = 6
constant integer ACTUAL_INPUT_TV_1    = 7
constant integer ACTUAL_INPUT_COMPONENT_1    = 8
constant integer ACTUAL_INPUT_OPTION_1    = 9
constant integer ACTUAL_INPUT_COMPONENT_2    = 10
constant integer ACTUAL_INPUT_DISPLAYPORT_1    = 11
constant integer ACTUAL_INPUT_HDMI_1    = 12
constant integer ACTUAL_INPUT_HDMI_2    = 13
constant integer ACTUAL_INPUT_DISPLAYPORT_2    = 14

constant integer REQUIRED_MUTE_ON    = 1
constant integer REQUIRED_MUTE_OFF    = 2

constant integer ACTUAL_MUTE_ON    = 1
constant integer ACTUAL_MUTE_OFF    = 2

constant integer GET_POWER    = 1
constant integer GET_INPUT    = 2
constant integer GET_MUTE    = 3
constant integer GET_VOLUME    = 4

constant integer COMM_MODE_ONE_WAY    = 1
constant integer COMM_MODE_TWO_WAY    = 2
constant integer COMM_MODE_ONE_WAY_BASIC    = 3


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile integer iLoop

volatile _NAVDisplay uDisplay

volatile char cUnitID[2] = '01'
volatile integer iUnitID

volatile integer iCommMode    = COMM_MODE_TWO_WAY    //Default Two-Way

volatile integer iID

volatile char iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile char iCommandLockOut

volatile integer iPollSequence = GET_POWER


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

define_function SendCommand(char cParam[]) {
    // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Command to ',NAVStringSurroundWith(NAVDeviceToString(vdvCommObject), '[', ']'),': [',cParam,']'")
    send_command vdvCommObject,"cParam"
}


define_function BuildCommand(char cHeader[], char cCmd[]) {
    if (length_array(cCmd)) {
        SendCommand("cHeader,'-<',itoa(iID),'|',cCmd,'>'")
    }
    else {
        SendCommand("cHeader,'-<',itoa(iID),'>'")
    }
}


define_function char[NAV_MAX_BUFFER] BuildString(char cCmd[], char cUnitID[], char cVal[]) {
    stack_var char cTemp[100]
    if (length_array(cCmd)) { cTemp = "cTemp,cCmd,' '" }
    if (length_array(cUnitID)) { cTemp = "cTemp,cUnitID,' '" }
    if (length_array(cVal)) { cTemp = "cTemp,cVal" }
    return cTemp
}


define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]

    iSemaphore = true

    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,'>')) {
        cTemp = remove_string(cRxBuffer,"'>'",1)

        if (!length_array(cTemp)) {
            continue
        }

        // NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Parsing String From ',NAVStringSurroundWith(NAVDeviceToString(vdvCommObject), '[', ']'),': [',cTemp,']'")
        if (NAVContains(cRxBuffer, cTemp)) { cRxBuffer = "''" }

        select {
            active (NAVStartsWith(cTemp,'REGISTER')): {
                iID = atoi(NAVGetStringBetween(cTemp,'<','>'))
                if (iID) { BuildCommand('REGISTER','') }
                NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_REGISTER_REQUESTED<',itoa(iID),'>'")
                NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_REGISTER<',itoa(iID),'>'")
            }
            active (NAVStartsWith(cTemp,'INIT')): {
                NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_INIT_REQUESTED<',itoa(iID),'>'")

                switch (iCommMode) {
                    case COMM_MODE_TWO_WAY: {
                        module.Device.IsInitialized = false
                        GetInitialized()
                    }
                    case COMM_MODE_ONE_WAY:
                    case COMM_MODE_ONE_WAY_BASIC: {
                        module.Device.IsInitialized = true
                        BuildCommand('INIT_DONE','')
                        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_INIT_DONE<',itoa(iID),'>'")
                    }
                }
            }
            active (NAVStartsWith(cTemp,'START_POLLING')): {
                NAVTimelineStart(TL_DRIVE,
                                TL_DRIVE_INTERVAL,
                                TIMELINE_ABSOLUTE,
                                TIMELINE_REPEAT)
            }
            active (NAVStartsWith(cTemp,'RESPONSE_MSG')): {
                stack_var char cResponseRequestMess[NAV_MAX_BUFFER]
                stack_var char cResponseMess[NAV_MAX_BUFFER]

                //NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'RESPONCE_MSG_RECEIVED<',itoa(iID),'>: ',cTemp")
                TimeOut()

                cResponseRequestMess = NAVGetStringBetween(cTemp,'<','|')
                cResponseMess = NAVGetStringBetween(cTemp,'|','>')
                BuildCommand('RESPONSE_OK',cResponseRequestMess)

                {
                    stack_var char cCmd[1]
                    stack_var char cResponseUnitID[2]

                    cCmd = NAVStripCharsFromRight(remove_string(cResponseMess,' ',1),1)
                    cResponseUnitID = NAVStripCharsFromRight(remove_string(cResponseMess,' ',1),1)

                    if (cResponseUnitID == cUnitID) {    //Sanity check
                        remove_string(cResponseMess,'OK',1)

                        switch (lower_string(cCmd)) {
                            case 'a': {    //Power State Get
                                switch (cResponseMess) {    //Whats left is the state
                                    case '00': { uDisplay.PowerState.Actual = ACTUAL_POWER_OFF }
                                    case '01': { uDisplay.PowerState.Actual = ACTUAL_POWER_ON }
                                }


                                if (!module.Device.IsInitialized) {
                                    module.Device.IsInitialized = true
                                    BuildCommand('INIT_DONE','')
                                    NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'LG_INIT_DONE<',itoa(iID),'>'")
                                }

                                UpdateFeedback()
                            }
                            case 'b': {    //Current Source Get
                                switch (cResponseMess) {    //Whats left is the input val
                                    case '60': { uDisplay.Input.Actual = ACTUAL_INPUT_VGA_1 }
                                    case '20': { uDisplay.Input.Actual = ACTUAL_INPUT_VIDEO_1 }
                                    case '21': { uDisplay.Input.Actual = ACTUAL_INPUT_SVIDEO_1 }
                                    case '40': { uDisplay.Input.Actual = ACTUAL_INPUT_COMPONENT_1 }
                                    case '90': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_1 }
                                    case '91': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_2 }
                                }

                                UpdateFeedback()
                                iPollSequence = GET_POWER
                            }
                        }
                    }
                }
            }
        }
    }

    iSemaphore = false
}


define_function GetInitialized() {
    SendQuery(GET_POWER)
    SendQuery(GET_INPUT)
   // SendQuery(GET_MUTE)
   // SendQuery(GET_VOLUME)
}


define_function SendQuery(integer iParam) {
    switch (iParam) {
        case GET_POWER: { BuildCommand('POLL_MSG',BuildString('ka',cUnitID,'FF')) }
        case GET_INPUT: { BuildCommand('POLL_MSG',BuildString('xb',cUnitID,'FF')) }
    }
}


define_function TimeOut() {
    module.Device.IsCommunicating = true

    cancel_wait 'CommsTimeOut'

    wait 300 'CommsTimeOut' {
        module.Device.IsCommunicating = false
    }
}


define_function SetPower(integer iParam) {
    switch (iParam) {
        case REQUIRED_POWER_ON: { BuildCommand('COMMAND_MSG',BuildString('ka',cUnitID,'1')) }
        case REQUIRED_POWER_OFF: { BuildCommand('COMMAND_MSG',BuildString('ka',cUnitID,'0')) }
    }
}


define_function SetInput(integer iParam) {
    switch (iParam) {
        case REQUIRED_INPUT_VGA_1: { BuildCommand('COMMAND_MSG',BuildString('xb',cUnitID,'60')) }
        case REQUIRED_INPUT_VIDEO_1: { BuildCommand('COMMAND_MSG',BuildString('xb',cUnitID,'20')) }
        case REQUIRED_INPUT_SVIDEO_1: { BuildCommand('COMMAND_MSG',BuildString('xb',cUnitID,'21')) }
        case REQUIRED_INPUT_COMPONENT_1: { BuildCommand('COMMAND_MSG',BuildString('xb',cUnitID,'40')) }
        case REQUIRED_INPUT_HDMI_1: { BuildCommand('COMMAND_MSG',BuildString('xb',cUnitID,'90')) }
        case REQUIRED_INPUT_HDMI_2: { BuildCommand('COMMAND_MSG',BuildString('xb',cUnitID,'91')) }
    }
}


define_function SetVolume(sinteger siParam) {
    BuildCommand('COMMAND_MSG', BuildString('kf',cUnitID,format('%02X', siParam)))
}


define_function Drive() {
    iLoop++

    switch (iLoop) {
        case 1:
        case 6:
        case 11:
        case 16: {
            if (iCommMode == COMM_MODE_TWO_WAY) {
                SendQuery(iPollSequence)
                return
            }
        }
        case 21: { iLoop = 0; return }
        default: {
            switch (iCommMode) {
                case COMM_MODE_ONE_WAY:
                case COMM_MODE_TWO_WAY: {
                    if (iCommandLockOut) { return }
                    if (uDisplay.PowerState.Required && (uDisplay.PowerState.Required == uDisplay.PowerState.Actual)) { uDisplay.PowerState.Required = 0; return }
                    if (uDisplay.Input.Required && (uDisplay.Input.Required == uDisplay.Input.Actual)) { uDisplay.Input.Required = 0; return }
                    if (uDisplay.Volume.Level.Required >= 0 && (uDisplay.Volume.Level.Required == uDisplay.Volume.Level.Actual)) { uDisplay.Volume.Level.Required = -1; return }

                    if (uDisplay.PowerState.Required && (uDisplay.PowerState.Required != uDisplay.PowerState.Actual) && module.Device.IsCommunicating) {
                        SetPower(uDisplay.PowerState.Required)
                        iCommandLockOut = true
                        switch (iCommMode) {
                            case COMM_MODE_ONE_WAY: { //One-Way
                                switch (uDisplay.PowerState.Required) {
                                    case REQUIRED_POWER_ON: {
                                        wait 80 {
                                            iCommandLockOut = false
                                        }
                                    }
                                    case REQUIRED_POWER_OFF: {
                                        wait 20 {
                                            iCommandLockOut = false
                                        }
                                    }
                                }

                                uDisplay.PowerState.Actual = uDisplay.PowerState.Required    //Emulate
                            }
                            case COMM_MODE_TWO_WAY: {
                                wait 20 iCommandLockOut = false
                            }
                        }

                        iPollSequence = GET_POWER
                        return
                    }

                    if (uDisplay.Input.Required && (uDisplay.Input.Required  != uDisplay.Input.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
                        SetInput(uDisplay.Input.Required)
                        if (iCommMode == COMM_MODE_ONE_WAY) {    //One-Way
                            uDisplay.Input.Actual = uDisplay.Input.Required    //Emulate
                        }

                        iCommandLockOut = true
                        wait 20 iCommandLockOut = false
                        iPollSequence = GET_INPUT
                        return
                    }

                    if ([vdvObject,VOL_UP] && uDisplay.PowerState.Actual == ACTUAL_POWER_ON) { uDisplay.Volume.Level.Required++ }
                    if ([vdvObject,VOL_DN] && uDisplay.PowerState.Actual == ACTUAL_POWER_ON) { uDisplay.Volume.Level.Required-- }

                    if (uDisplay.Volume.Level.Required && (uDisplay.Volume.Level.Required != uDisplay.Volume.Level.Actual) && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && module.Device.IsCommunicating) {
                        SetVolume(uDisplay.Volume.Level.Required)
                        iCommandLockOut = true
                        wait 5 iCommandLockOut = false
                        iPollSequence = GET_VOLUME
                        return
                    }
                }
                case COMM_MODE_ONE_WAY_BASIC: {
                    if (uDisplay.PowerState.Required) { SetPower(uDisplay.PowerState.Required); uDisplay.PowerState.Required = 0; NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'LG_SENDING_POWER_COMMAND_TO_COMM') }
                    if (uDisplay.Input.Required) { SetInput(uDisplay.Input.Required); uDisplay.Input.Required = 0; NAVErrorLog(NAV_LOG_LEVEL_DEBUG, 'LG_SENDING_INPUT_COMMAND_TO_COMM') }
                }
            }
        }
    }
}


define_function UpdateFeedback() {
    if (iCommMode == COMM_MODE_TWO_WAY) [vdvObject,POWER_FB]    = (uDisplay.PowerState.Actual == ACTUAL_POWER_ON)
    if (iCommMode == COMM_MODE_TWO_WAY) [vdvObject,DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject,DATA_INITIALIZED] = (module.Device.IsInitialized)
    if (iCommMode == COMM_MODE_TWO_WAY) [vdvObject,VOL_MUTE_FB]    = (uDisplay.Volume.Mute.Actual == ACTUAL_MUTE_ON)
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer vdvCommObject,cRxBuffer
    uDisplay.Volume.Level.Required = -1
    uDisplay.Volume.Level.Actual = -1
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvCommObject] {
    string: {
        if (!iSemaphore) {
            Process()
        }
    }
}


data_event[vdvObject] {
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[3][NAV_MAX_CHARS]

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Command from ',NAVStringSurroundWith(NAVDeviceToString(data.device), '[', ']'),': [',data.text,']'")

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)
        cCmdParam[3] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'PROPERTY': {
                switch (cCmdParam[1]) {
                    case 'UNIT_ID': {
                        cUnitID = cCmdParam[2]
                    }
                    case 'COMM_MODE': {
                        switch (cCmdParam[2]) {
                            case 'ONE-WAY': { //One-Way
                                switch (cCmdParam[3]) {
                                    case 'BASIC': { iCommMode = COMM_MODE_ONE_WAY_BASIC }
                                    case 'ADVANCED': { iCommMode = COMM_MODE_ONE_WAY }
                                }

                                module.Device.IsCommunicating = true    //Force it
                            }
                            case 'TWO-WAY': { //Two-Way
                                iCommMode = COMM_MODE_TWO_WAY
                            }
                        }
                    }
                }
            }
            case 'ADJUST': {}
            case 'POWER': {
                switch (cCmdParam[1]) {
                    case 'ON': {
                        uDisplay.PowerState.Required = REQUIRED_POWER_ON
                        Drive()
                    }
                    case 'OFF': {
                        uDisplay.PowerState.Required = REQUIRED_POWER_OFF
                        uDisplay.Input.Required = 0
                        Drive()
                    }
                }
            }
            case 'INPUT': {
                switch (cCmdParam[1]) {
                    case 'VGA': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_VGA_1
                                Drive()
                            }
                        }
                    }
                    case 'DVI': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_DVI_1
                                Drive()
                            }
                        }
                    }
                    case 'COMPOSITE': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_VIDEO_1
                                Drive()
                            }
                        }
                    }
                    case 'S-VIDEO': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_SVIDEO_1
                                Drive()
                            }
                        }
                    }
                    case 'COMPONENT': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_RGB_1
                                Drive()
                            }
                        }
                    }
                    case 'DISPLAYPORT': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_DISPLAYPORT_1
                                Drive()
                            }
                            case '2': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_DISPLAYPORT_2
                                Drive()
                            }
                        }
                    }
                    case 'HDMI': {
                        switch (cCmdParam[2]) {
                            case '1': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_HDMI_1
                                Drive()
                            }
                            case '2': {
                                if (iCommMode != COMM_MODE_ONE_WAY_BASIC) {
                                    uDisplay.PowerState.Required = REQUIRED_POWER_ON
                                }

                                uDisplay.Input.Required = REQUIRED_INPUT_HDMI_2
                                Drive()
                            }
                        }
                    }
                }
            }
        }
    }
}


channel_event[vdvObject, 0] {
    on: {
        switch (channel.channel) {
            case PWR_ON: {
                uDisplay.PowerState.Required = REQUIRED_POWER_ON
                Drive()
            }
            case PWR_OFF: {
                uDisplay.PowerState.Required = REQUIRED_POWER_OFF
                uDisplay.Input.Required = 0
                Drive()
            }
        }
    }
}


timeline_event[TL_DRIVE] { Drive(); }


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
