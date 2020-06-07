//
//  ContentView.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/5/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import SwiftUI

import URLImage

struct Tooltip: NSViewRepresentable {
    let tooltip: String
    func makeNSView(context: NSViewRepresentableContext<Tooltip>) -> NSView {
        let view = NSView()
        view.toolTip = tooltip
        return view
    }
    func updateNSView(_ nsView: NSView, context: NSViewRepresentableContext<Tooltip>) {
    }
}

struct ContentView: View {
    @ObservedObject var apkStore: ApkStore = ApkStore.sharedInstance
    @ObservedObject var deviceStore: DeviceStore = DeviceStore.sharedInstance
    
    @State private var forceInstallEnabled = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: Constants.paddingAndCorderRadius) {
            HStack {
                ApkList()
                DeviceList()
            }
            HStack(alignment: .center, spacing: Constants.paddingAndCorderRadius) {
                Toggle(isOn: $forceInstallEnabled) {
                    Text("Force Install")
                        .overlay(Tooltip(tooltip: "It will uninstall the app with same package name first."))
                }
                .disabled(apkStore.loading)
                Spacer()
                Button(action: {
                    DeviceService.install(force: self.forceInstallEnabled)
                }) {
                    HStack {
                        Image(nsImage: NSImage(named: NSImage.followLinkFreestandingTemplateName)!)
                            .foregroundColor(.white)
                        Text("Install")
                            .foregroundColor(.white)
                    }
                    .padding(Constants.paddingAndCorderRadius)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.green))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(apkStore.selectedApks.isEmpty || deviceStore.selectedDevices.isEmpty || deviceStore.isBusy)
            }
            
        }.padding(Constants.paddingAndCorderRadius)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
