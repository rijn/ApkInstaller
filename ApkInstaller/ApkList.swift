//
//  ApkList.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/5/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import SwiftUI

import URLImage

struct ApkList: View {
    @ObservedObject var apkStore: ApkStore = ApkStore.sharedInstance

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.paddingAndCorderRadius) {
            Button(action: {
                ApkService.refresh()
            }) {
                HStack {
                    if apkStore.loading {
                        ProgressIndicator(style: .constant(NSProgressIndicator.Style.spinning))
                    } else {
                        Image(nsImage: NSImage(named: NSImage.refreshTemplateName)!)
                            .foregroundColor(.white)
                    }
                    
                    Text("Refresh APK List")
                        .foregroundColor(.white)
                }
                .padding(Constants.paddingAndCorderRadius)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(apkStore.loading)
            List(apkStore.apks, selection: $apkStore.selectedApks) { apk in
                HStack {
                    if apk.label != nil {
                        apk.iconUrl.map { URLImage($0) }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(apk.label ?? "").font(.headline)
                            Text(apk.package ?? "").lineLimit(1).truncationMode(.head)
                        }.padding(Constants.paddingAndCorderRadius)
                    } else {
                        ProgressIndicator(style: .constant(NSProgressIndicator.Style.spinning))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(apk.fileName).font(.headline)
                            Text(apk.id).lineLimit(1).truncationMode(.head)
                        }.padding(Constants.paddingAndCorderRadius)
                    }
                }
            }.cornerRadius(Constants.paddingAndCorderRadius)
        }.onAppear(perform: {
            ApkService.refresh()
        })
    }
}

struct ApkList_Previews: PreviewProvider {
    static var previews: some View {
        ApkList()
    }
}
