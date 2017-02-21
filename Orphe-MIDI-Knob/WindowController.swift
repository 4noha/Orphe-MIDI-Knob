//
//  WindowController.swift
//  Orphe-MIDI-Knob
//
//  Created by nokkii on 2017/02/22.
//  Copyright © 2017年 nokkii. All rights reserved.
//

import Cocoa

class WindowController: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window!.delegate = self
    }
    
}

extension WindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared().terminate(NSApp.keyWindow!)
    }
}
