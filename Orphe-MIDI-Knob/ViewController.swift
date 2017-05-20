//
//  ViewController.swift
//  Orphe-MIDI-Knob
//
//  Created by nokkii on 2017/02/21.
//  Copyright © 2017年 nokkii. All rights reserved.
//

import Cocoa
import Orphe
import CoreMIDI
import AVFoundation

class ViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var leftSensorLabel: NSTextField!
    @IBOutlet weak var rightSensorLabel: NSTextField!
    @IBOutlet weak var rightSwitchButton: NSButton!
    @IBOutlet weak var ToggleTapButton: NSButton!
    
    var bassPlayer: AVAudioPlayer!
    var hatPlayer: AVAudioPlayer!
    let bassPath = NSURL(fileURLWithPath: Bundle.main.path(forResource: "bass", ofType: "aiff")!)
    let hatPath = NSURL(fileURLWithPath: Bundle.main.path(forResource: "hat", ofType: "aiff")!)
    
    var rssiTimer: Timer?
    
    var leftGesture = ""
    var rightGesture = ""
    var times = 0
    var EULER_RANGE = 38.0
    
    var lower_euler_l0 = Double(-38.0)
    var upper_euler_l0 = Double(0.0)
    var calibrate_lcnt = 0
    var calibrate_ltmp = Double(0.0)
    
    var lower_euler_r0 = Double(-38.0)
    var upper_euler_r0 = Double(0.0)
    var calibrate_rcnt = 0
    var calibrate_rtmp = Double(0.0)
    
    var leftOrphe: ORPData?
    var rightOrphe: ORPData?
    
    var tapMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MIDI
        MIDIInterface.sharedInstance.initMIDI()
        
        //let musicSequence = MIDIInterface.sharedInstance.createMusicSequence()
        //MIDIInterface.sharedInstance.createPlayer(musicSequence: musicSequence)
        //MIDIInterface.sharedInstance.startPlaying()
        
        //Dramns
        do{
            bassPlayer = try AVAudioPlayer(contentsOf: bassPath as URL)
            hatPlayer = try AVAudioPlayer(contentsOf: hatPath as URL)
        }
        catch{}
        bassPlayer.delegate = self as? AVAudioPlayerDelegate
        hatPlayer.delegate = self as? AVAudioPlayerDelegate
        
        // View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.allowsTypeSelect = false
        
        ORPManager.sharedInstance.delegate = self
        ORPManager.sharedInstance.isEnableAutoReconnection = false
        ORPManager.sharedInstance.startScan()
        
        rssiTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(ViewController.readRSSI), userInfo: nil, repeats: true)
    }
    
    
    override var representedObject: Any? {
        didSet {
            
        }
    }
    
    
    func updateCellsState(){
        for (index, orp) in ORPManager.sharedInstance.availableORPDataArray.enumerated(){
            for (columnNum, _) in tableView.tableColumns.enumerated(){
                if let cell = tableView.view(atColumn: columnNum, row: index, makeIfNecessary: true) as? NSTableCellView{
                    if orp.state() == .connected{
                        cell.textField?.textColor = NSColor.yellow
                        cell.textField?.backgroundColor = NSColor.darkGray
                    }
                    else{
                        cell.textField?.textColor = NSColor.black
                        cell.textField?.backgroundColor = NSColor.white
                    }
                }
            }
            
        }
    }
    
    
    override func keyDown(with theEvent: NSEvent){
        super.keyDown(with: theEvent)
        
        if let lightNum:UInt8 = UInt8(theEvent.characters!) {
            for orp in ORPManager.sharedInstance.connectedORPDataArray{
                orp.triggerLight(lightNum: lightNum)
            }
        }
    }
    
    
    @IBAction func rightSwitchButtonAction(sender : AnyObject) {
        if (leftOrphe != nil) {
            leftOrphe?.requestChangeSide(ORPSide.right)
            rightOrphe = leftOrphe
            leftOrphe = nil
        }
    }
    
    @IBAction func ToggleTapButtonAction(sender : AnyObject) {
        tapMode = !tapMode
        
        if tapMode {
            ToggleTapButton.title = "disable Tap Mode"
        }
        else {
            ToggleTapButton.title = "enable Tap Mode"
        }
    }
}


extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?{
        let cellIdentifier: String = "NameCell"
        
        if let cell = tableView.make(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            if tableColumn == tableView.tableColumns[0] {
                cell.textField?.stringValue = ORPManager.sharedInstance.availableORPDataArray[row].name
                cell.textField?.drawsBackground = true
            }
            else if tableColumn == tableView.tableColumns[1] {
                cell.textField?.stringValue = "0"
                cell.textField?.drawsBackground = true
            }
            return cell
        }
        return nil
    }
    
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow != -1 {
            let orp = ORPManager.sharedInstance.availableORPDataArray[tableView.selectedRow]
            
            if orp.state() == .disconnected {
                ORPManager.sharedInstance.connect(orphe: orp)
                
                if Int32(orp.side.rawValue) == 0 {
                    leftOrphe = orp;
                }
                else {
                    rightOrphe = orp;
                }
            }
            else {
                ORPManager.sharedInstance.disconnect(orphe: orp)
            }
        }
    }
}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ORPManager.sharedInstance.availableORPDataArray.count
    }
}


extension ViewController: ORPManagerDelegate {
    //MARK: - ORPManagerDelegate
    func orpheDidUpdateBLEState(state:CBCentralManagerState){
        PRINT("didUpdateBLEState", state)
        
        switch state {
        case .poweredOn:
            ORPManager.sharedInstance.startScan()
        default:
            break
        }
    }
    
    
    func orpheDidUpdateRSSI(orphe:ORPData){
        // print("didUpdateRSSI", orphe.RSSI)
        if let index = ORPManager.sharedInstance.availableORPDataArray.index(of: orphe){
            if let cell = tableView.view(atColumn: 1, row: index, makeIfNecessary: false) as? NSTableCellView{
                cell.textField?.stringValue = String(describing: orphe.RSSI)
            }
        }
    }
    
    
    func orpheDidDiscoverOrphe(orphe:ORPData){
        PRINT("didDiscoverOprhe")
        tableView.reloadData()
        updateCellsState()
    }
    
    
    func orpheDidDisappearOrphe(orphe:ORPData){
        PRINT("didDisappearOprhe")
        tableView.reloadData()
        updateCellsState()
    }
    
    
    func orpheDidFailToConnect(orphe:ORPData){
        PRINT("didFailToConnect")
        tableView.reloadData()
        updateCellsState()
    }
    
    
    func orpheDidDisconnect(orphe:ORPData){
        PRINT("didDisconnect")
        tableView.reloadData()
        updateCellsState()
    }
    
    
    func orpheDidConnect(orphe:ORPData){
        PRINT("didConnect")
        tableView.reloadData()
        updateCellsState()
        
        orphe.setScene(ORPScene.sceneSDK)
        orphe.setGestureSensitivity(ORPGestureSensitivity.high)
    }
    
    
    func orpheDidUpdateOrpheInfo(orphe:ORPData){
        PRINT("didUpdateOrpheInfo")
        
        for orp in ORPManager.sharedInstance.connectedORPDataArray {
            if orp != orphe && orp.side == orphe.side{
                orp.switchToOppositeSide()
                PRINT("switch to opposite side")
            }
        }
    }
    
    
    //MARK: - Others
    func readRSSI(){
        for orphe in ORPManager.sharedInstance.connectedORPDataArray {
            orphe.readRSSI()
        }
    }
    
    
    func orpheDidUpdateSensorData(orphe: ORPData) {
        let sideInfo:Int32 = Int32(orphe.side.rawValue)
        var text = ""
        let quat = orphe.getQuat()
        for (i, q) in quat.enumerated() {
            text += "Quat\(i): "+String(q) + "\n"
        }
        
        let euler = orphe.getEuler()
        for (i, e) in euler.enumerated() {
            text += "Euler\(i): "+String(e) + "\n"
        }
        
        let acc = orphe.getAcc()
        for (i, a) in acc.enumerated() {
            text += "Acc\(i): "+String(a) + "\n"
        }
        
        let gyro = orphe.getGyro()
        for (i, g) in gyro.enumerated() {
            text +=  "Gyro\(i): "+String(g) + "\n"
        }
        
        let mag = orphe.getMag()
        text +=  "Mag: "+String(mag) + "\n"
        
        let shock = orphe.getShock()
        text += "Shock: "+String(shock) + "\n"
        
        // PitchBenderKnob (0 ~ 16383)
        let knob = getPitchbendValue(euler0: Double(euler[0]))
        text += "Knob: "+String(knob) + "\n"
        
        var mutOrphe = ORPManager.sharedInstance.getOrpheData(idNumber: orphe.idNumber);
        if sideInfo == 0 {
            leftSensorLabel.stringValue = "LEFT\n\n" + text + "\n" + leftGesture
            calibrateFloor(sum: &calibrate_ltmp, cnt: &calibrate_lcnt, upper: &upper_euler_l0,
                           lower: &lower_euler_l0, euler: Double(euler[0]))
            changeColor(orphe: &mutOrphe!, knob: Int(knob))
            
            if !tapMode {
                MIDIInterface.sharedInstance.ccPitchbendReceive(ch:1, pitchbendValue: knob)
            }
        }
        else{
            rightSensorLabel.stringValue = "RIGHT\n\n" + text + "\n" + rightGesture
            calibrateFloor(sum: &calibrate_rtmp, cnt: &calibrate_rcnt, upper: &upper_euler_r0,
                           lower: &lower_euler_r0, euler: Double(euler[0]))
            changeColor(orphe: &mutOrphe!, knob: Int(knob))
            
            if !tapMode {
                MIDIInterface.sharedInstance.ccPitchbendReceive(ch:2, pitchbendValue: knob)
            }
        }
    }
    
    
    func orpheDidCatchGestureEvent(gestureEvent:ORPGestureEventArgs, orphe:ORPData) {
        let side = orphe.side
        let kind = gestureEvent.getGestureKindString() as String
        let power = gestureEvent.getPower()
        if side == ORPSide.left {
            if tapMode {
                bassPlayer.play()
            }
            leftGesture = "Gesture: " + kind + "\n"
            leftGesture += "power: " + String(power)
        }
        else{
            if tapMode {
                hatPlayer.play()
            }
            rightGesture = "Gesture: " + kind + "\n"
            rightGesture += "power: " + String(power)
        }
    }
    
    
    func getPitchbendValue(euler0:Double) -> UInt16 {
        var pitch = euler0 - upper_euler_l0
        if pitch < lower_euler_l0 {
            pitch = lower_euler_l0
        }else if euler0 > upper_euler_l0{
            pitch = Double(0.0)
        }
        let pitchbendValue = UInt16(Int16(pitch * (16383.0 / lower_euler_l0)))
        
        return pitchbendValue
    }
    
    
    func changeColor(orphe:inout ORPData, knob:Int) {
        if times < 3 {
            times += 1
        } else {
            let red = UInt8((knob + 5461) <= 10922 ? 255 - (255 * (knob + 5461) / 10922) : 0)
            let green = UInt8((knob - 5461) > 0 ? (255 * (knob - 5461) / 10922) : 0)
            
            orphe.setColorRGB(lightNum:0, red:red, green:green, blue:0)
            orphe.switchLight(lightNum:0, flag:true)
            times = 0
        }
    }
    
    
    func calibrateFloor(sum:inout Double, cnt:inout Int, upper:inout Double, lower:inout Double, euler:Double) {
        PRINT(String(cnt))
        if euler > -5.0 && euler < 5.0 {
            sum += euler
            cnt += 1
            print(String(cnt))
            
            if cnt > 99 {
                print("Floor calibration!" + String(sum / Double(cnt)))
                upper = sum / Double(cnt)
                lower = upper - EULER_RANGE
                cnt = 0
                sum = Double(0.0)
            }
        }
    }
}

