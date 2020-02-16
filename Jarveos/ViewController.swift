//
//  ViewController.swift
//  Jarveos
//
//  Created by Sam Smallman on 04/08/2015.
//  Copyright (c) 2015 Sam Smallman. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSSpeechRecognizerDelegate, F53OSCPacketDestination, F53OSCClientDelegate {

    @IBOutlet weak var ipAddress: NSTextField!
    @IBOutlet weak var receivePort: NSTextField!
    @IBOutlet weak var transmitPort: NSTextField!
    @IBOutlet weak var useTCPConnection: NSButton!
    @IBOutlet weak var toggleConnection: NSButton!
    
    var jarvisIsListening:Bool = false
    var jarvisIsConnected:Bool = false
    var numberOfCues:Int = 0
    var numberOfCueLists:Int = 0
    var activeCue:String = "0"
    var goToCueCommands:[String] = []
    
    lazy var jarvis = NSSpeechRecognizer()
    let jarvisSpeech = NSSpeechSynthesizer()
    let commands = ["Ping", "Go" , "Stop Back", "Go To Cue 0", "Go To Cue Out", "What Cue?", "How Many Cue Lists?"]
    
    private let eosSubscribe = F53OSCMessage(addressPattern: "/eos/subscribe", arguments: [1])
    private let eosUnSubscribe = F53OSCMessage(addressPattern: "/eos/subscribe", arguments: [0])
    private let eosGoDownMessage = F53OSCMessage(addressPattern: "/eos/key/Go 0", arguments: [1])
    private let eosGoUpMessage = F53OSCMessage(addressPattern: "/eos/key/Go 0", arguments: [0])
    private let eosStopDownMessage = F53OSCMessage(addressPattern: "/eos/key/Stop", arguments: [1])
    private let eosStopUpMessage = F53OSCMessage(addressPattern: "/eos/key/Stop", arguments: [0])
    private let eosGoToCueOut = F53OSCMessage(string: "/eos/newcmd/Go_To_Cue/Out/Enter")
    private let eosGoToCueZero = F53OSCMessage(string: "/eos/newcmd/Go_To_Cue/0/Enter")
    private let eosPingMessage = F53OSCMessage(string: "/eos/ping")
    private let eosRequestCueCountMessage = F53OSCMessage(string: "/eos/get/cue/1/count")
    private let eosRequestCueListCountMessage = F53OSCMessage(string: "/eos/get/cuelist/count")
    private let tcpClient = F53OSCClient()
    private let udpServer = F53OSCServer()
    private let udpClient = F53OSCClient()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
//        jarvis!.commands = commands
//        jarvis!.delegate = self
        tcpClient.delegate = self
        tcpClient.useTcp = true
        udpServer.delegate = self
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    @IBAction func connection(sender: AnyObject) {
        if jarvisIsConnected == false {
            connect()
        } else {
            disconnect()
        }
    }
    
    func connect() {
        let strRawTarget: String? = ipAddress.stringValue
        let validIpAddressRegex = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
        if (strRawTarget!.rangeOfString(validIpAddressRegex, options: .RegularExpressionSearch) != nil) {
            if useTCPConnection.state == NSOnState {
                tcpClient.port = 3032
                tcpClient.host = ipAddress.stringValue
                print("Connecting Via TCP")
                print("IP Address: \(ipAddress.stringValue)")
                print("Port: \(tcpClient.port)")
                tcpClient.connect()
                tcpClient.sendPacket(eosPingMessage)
//                tcpClient.sendPacket(eosRequestCueCountMessage)
                tcpClient.sendPacket(eosRequestCueListCountMessage)
                tcpClient.sendPacket(eosSubscribe)
            } else {
                if let recivePort = Int(receivePort.stringValue), transmitPort = Int(transmitPort.stringValue) {
                    udpServer.port = UInt16(recivePort)
                    udpClient.port = UInt16(transmitPort)
                    udpClient.host = ipAddress.stringValue
                    print("Connecting Via UDP")
                    print("IP Address: \(ipAddress.stringValue)")
                    print("Receive Port: \(udpServer.port)")
                    print("Transmit Port: \(udpClient.port)")
                    udpServer.startListening()
                    udpClient.sendPacket(eosPingMessage)
                    connected()
//                    udpClient.sendPacket(eosRequestCueCountMessage)
                    udpClient.sendPacket(eosRequestCueListCountMessage)
                    udpClient.sendPacket(eosSubscribe)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Please enter a valid Receive/Transmit Port"
                    alert.informativeText = "You can find your consoles OSC Receive/Transmit Ports by pressing [Displays], {Setup}, {Show Control}."
                    alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
                }
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "Please enter a valid IP Address"
            alert.informativeText = "You can find your consoles IP Address by press and holding [Tab], then tapping [99], then releasing [Tab]."
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
        }
    }
    @IBAction func toggleConnectionType(sender: AnyObject) {
        if useTCPConnection.state == NSOnState {
            tcpClient.port = 3032
            receivePort.stringValue = "3032"
            receivePort.enabled = false
            transmitPort.stringValue = "3032"
            transmitPort.enabled = false
        } else {
            receivePort.stringValue = ""
            receivePort.enabled = true
            transmitPort.stringValue = ""
            transmitPort.enabled = true
        }
    }
    
    func disconnect() {
        if useTCPConnection.state == NSOnState {
            tcpClient.disconnect()
            print("TCP Connection did Disconnect")
        } else {
            udpServer.stopListening()
            print("UDP Connection did Stop Listening")
        }
        disconnected()
        jarvis!.commands = commands
        
    }
    
    func connected() {
        jarvisIsConnected = true
        ipAddress.enabled = false
        receivePort.enabled = false
        transmitPort.enabled = false
        useTCPConnection.enabled = false
        toggleConnection.title = "Disconnect"
        jarvis!.startListening()
        jarvisIsListening = true
    }
    
    func disconnected() {
        jarvisIsConnected = false
        if useTCPConnection.state == NSOnState {
            receivePort.enabled = false
            transmitPort.enabled = false
        } else {
            receivePort.enabled = true
            transmitPort.enabled = true
        }
        jarvis!.stopListening()
        jarvisIsListening = false
        useTCPConnection.enabled = true
        ipAddress.enabled = true
        toggleConnection.title = "Connect"
    }
    
    func speechRecognizer(sender: NSSpeechRecognizer, didRecognizeCommand command: String) {
        if jarvisIsConnected == true {
            var client: F53OSCClient?
            if useTCPConnection.state == NSOnState {
                client = tcpClient
            } else {
                client = udpClient
            }
            switch command {
            case "Go":
                print("Go")
                client!.sendPacket(eosGoDownMessage)
                client!.sendPacket(eosGoUpMessage)
            case "Stop Back":
                print("Stop Back")
                client!.sendPacket(eosStopDownMessage)
                client!.sendPacket(eosStopUpMessage)
            case "Ping":
                print("Ping")
                client!.sendPacket(eosPingMessage)
            case "Go To Cue 0":
                print("Go To Cue 0")
                client!.sendPacket(eosGoToCueZero)
            case "Go To Cue Out":
                print("Go To Cue Out")
                client!.sendPacket(eosGoToCueOut)
            case "What Cue?":
                print("You are sat in Cue \(activeCue)")
                jarvisSpeech.startSpeakingString("You are sat in Cue \(activeCue)")
            case "How Many Cue Lists?":
                print("There are \(numberOfCueLists) Cue Lists")
                if numberOfCueLists == 1 {
                    jarvisSpeech.startSpeakingString("There is only \(numberOfCueLists) Cue List")
                } else {
                    jarvisSpeech.startSpeakingString("There is \(numberOfCueLists) Cue Lists")
                }
            case _ where command.rangeOfString("Load Cue List") != nil:
                print(command)
                let cueListNumber = cueNumberFromSpeech(fromString: command)
                let eosLoadCueList = F53OSCMessage(string: "/eos/newcmd/loadcue/\(cueListNumber)\\Enter")
                client!.sendPacket(eosLoadCueList)
            default:
                for command in jarvis!.commands! {
                    print("Go To Cue: \(command)")
                    print(cueNumberFromSpeech(fromString: command))
                    let cueNumber = cueNumberFromSpeech(fromString: command)
                    let eosGoToCue = F53OSCMessage(string: "/eos/cue/1/\(cueNumber)/fire")
                    client!.sendPacket(eosGoToCue)
                }
                print("I heard \(command)")
            }
        }
    }

    func clientDidConnect(client: F53OSCClient!) {
        connected()
    }

    func clientDidDisconnect(client: F53OSCClient!) {
        disconnected()
    }

    func cueListAndNumberFromString (fromString string: String) -> (String, String) {
        let delimiter = NSCharacterSet(charactersInString: "/")
        let stringComponents = string.componentsSeparatedByCharactersInSet(delimiter)
        let cueList = stringComponents[5]
        let cueNumber = stringComponents[6]
        return (cueList, cueNumber)
    }
    
    func cueNumberFromSpeech (fromString string: String) -> (String) {
        let delimiter = NSCharacterSet(charactersInString: " ")
        let stringComponents = string.componentsSeparatedByCharactersInSet(delimiter)
        let cueNumber = stringComponents.last
        return cueNumber!
    }

    func takeMessage(message: F53OSCMessage!) -> (Void){
        var client: F53OSCClient?
        if self.useTCPConnection.state == NSOnState {
            client = self.tcpClient
        } else {
            client = self.udpClient
        }
        switch message {
        case _ where message.addressPattern.rangeOfString("/eos/out/ping") != nil:
            connected()
        case _ where message.addressPattern.rangeOfString("/eos/out/active/cue/1/") != nil:
            activeCue = cueListAndNumberFromString(fromString: message.addressPattern).1
        case _ where message.addressPattern.rangeOfString("/eos/out/notify/cuelist/list/") != nil:
            jarvis!.commands = commands
            client!.sendPacket(eosRequestCueListCountMessage)
        case _ where message.addressPattern.rangeOfString("/eos/out/notify/cue/1/") != nil:
            jarvis!.commands = commands
            client!.sendPacket(eosRequestCueCountMessage)
        case _ where message.addressPattern.rangeOfString("/eos/out/get/cue/1/count") != nil:
            numberOfCues = message.arguments[0] as! Int
            let queue = NSOperationQueue()
            queue.addOperationWithBlock() {
                // do something in the background
                for i in 0..<self.numberOfCues {
                    let eosRequestCueInfoMessage = F53OSCMessage(string: "/eos/get/cue/1/index/\(i)")
                    client!.sendPacket(eosRequestCueInfoMessage)
                }
                NSOperationQueue.mainQueue().addOperationWithBlock() {
                    // when done, update your UI and/or model on the main queue
                    print("All cue Information has been requested")
                }
            }
        case _ where message.addressPattern.rangeOfString("/eos/out/get/cue/") != nil:
            if message.addressPattern.rangeOfString("/fx/") == nil && message.addressPattern.rangeOfString("/actions/") == nil && message.addressPattern.rangeOfString("/links/") == nil && message.addressPattern.rangeOfString("/count") == nil{
                let cueInfo = cueListAndNumberFromString(fromString: message.addressPattern)
                let arrayOfCommands = jarvis!.commands
                let newCommand = "Go To Cue \(cueInfo.1)"
                var commandsMatch = false
                for command in arrayOfCommands! {
                    if command == newCommand {
                        commandsMatch = true
                    }
                }
                if commandsMatch != true {
                    jarvis!.commands?.append(newCommand)
                }

            }
        case _ where message.addressPattern.rangeOfString("/eos/out/get/cuelist/count") != nil:
            numberOfCueLists = message.arguments[0] as! Int
            let queue = NSOperationQueue()
            queue.addOperationWithBlock() {
                // do something in the background
                for i in 0..<self.numberOfCueLists {
                    let eosRequestCueListInfoMessage = F53OSCMessage(string: "/eos/get/cuelist/index/\(i)")
                    client!.sendPacket(eosRequestCueListInfoMessage)
                }
                NSOperationQueue.mainQueue().addOperationWithBlock() {
                    // when done, update your UI and/or model on the main queue
                    print("All Cue List Information has been requested")
                }
            }
        case _ where message.addressPattern.rangeOfString("/eos/out/get/cuelist/") != nil:
            if message.addressPattern.rangeOfString("/links/") == nil && message.addressPattern.rangeOfString("/count") == nil{
                let cueInfo = cueListAndNumberFromString(fromString: message.addressPattern)
                let arrayOfCommands = jarvis!.commands
                let firstCommand = "Load Cue List \(cueInfo.0)"
                let secondCommand = "Cue List \(cueInfo.0) Out"
                var firstCommandMatch = false
                var secondCommandMatch = false
                for command in arrayOfCommands! {
                    if command == firstCommand {
                        firstCommandMatch = true
                    }
                    if command == secondCommand {
                        secondCommandMatch = true
                    }
                }
                if firstCommandMatch != true {
                    jarvis!.commands?.append(firstCommand)
                }
                if secondCommandMatch != true {
                    jarvis!.commands?.append(secondCommand)
                }
            }
        default:
//            print(message.addressPattern)
            break

        }
    }
}


