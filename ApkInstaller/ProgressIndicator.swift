//
//  ProgressIndicator.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/6/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import SwiftUI

struct ProgressIndicator: NSViewRepresentable {
    @Binding var style: NSProgressIndicator.Style
//    @Binding var progress: NSProgressIndicator.Style
    
    func makeNSView(context: NSViewRepresentableContext<ProgressIndicator>) -> NSProgressIndicator {
        let result = NSProgressIndicator()
        result.isIndeterminate = true
        result.startAnimation(nil)
        result.controlSize = NSControl.ControlSize.small
        result.appearance = NSAppearance(named: .darkAqua)
        return result
    }
    
    func updateNSView(_ nsView: NSProgressIndicator, context: NSViewRepresentableContext<ProgressIndicator>) {
        nsView.style = style
    }
}
