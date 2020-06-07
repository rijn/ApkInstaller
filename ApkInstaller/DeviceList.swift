//
//  DeviceList.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/5/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import SwiftUI

struct DeviceList: View {
    @ObservedObject var deviceStore: DeviceStore = DeviceStore.sharedInstance
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.paddingAndCorderRadius) {
            Button(action: {
                DeviceService.refresh()
            }) {
                HStack {
                    if deviceStore.isRefreshing {
                        ProgressIndicator(style: .constant(NSProgressIndicator.Style.spinning))
                    } else {
                        Image(nsImage: NSImage(named: NSImage.refreshTemplateName)!)
                            .foregroundColor(.white)
                    }
                    
                    Text("Refresh Device List")
                        .foregroundColor(.white)
                }
                .padding(Constants.paddingAndCorderRadius)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(deviceStore.isBusy)
            List(deviceStore.devices, selection: $deviceStore.selectedDevices) { device in
                HStack {
                    self.iconView(deviceInstallState: device.state)
                    //                        Image(nsImage: NSImage(named: NSImage.statusAvailableName)!)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(device.label ?? "").font(.headline)
                        Text(device.id)
                    }.padding(Constants.paddingAndCorderRadius)
                }
            }.cornerRadius(Constants.paddingAndCorderRadius)
        }
    }
    
    func iconView(deviceInstallState: DeviceInstallState) -> AnyView {
        switch deviceInstallState {
        case .standBy: return AnyView(Image(nsImage: NSImage(named: NSImage.statusAvailableName)!))
        case .pending: return AnyView(Image(nsImage: NSImage(named: NSImage.statusNoneName)!))
        case .installing: return AnyView(ProgressIndicator(style: .constant(NSProgressIndicator.Style.spinning)))
        case .installed: return AnyView(Image(nsImage: NSImage(named: NSImage.menuOnStateTemplateName)!))
        case .failed: return AnyView(Image(nsImage: NSImage(named: NSImage.statusUnavailableName)!))
        }
    }
}

struct DeviceList_Previews: PreviewProvider {
    static var previews: some View {
        DeviceList()
    }
}
