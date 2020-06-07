//
//  Apk.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/5/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import Foundation

import AppKit

import ZIPFoundation
import SWXMLHash

struct Apk: Hashable, Codable, Identifiable {
    var id: String
    
    var path: String
    var fileName: String
    
    var package: String?
    var label: String?
    var iconUrl: URL?
}

final class ApkStore: ObservableObject {
    static let sharedInstance = ApkStore()
    
    @Published var apks: [Apk] = []
    @Published var selectedApks: Set<String> = []
    
    @Published var loading: Bool = false
    
    func submit(newApks: [Apk]) {
        apks = newApks
    }
    
    func startLoad() {
        loading = true
    }
    
    func stopLoad() {
        loading = false
    }
}

final class ApkService {
    static func refresh() {
        ApkStore.sharedInstance.startLoad()
        
        DispatchQueue.global(qos: .background).async {
            
            let fileManager = FileManager()
        
            let destinationURL = fileManager.temporaryDirectory.appendingPathComponent("MilanInstaller")
            
            // Clear temporary folder
//            do {
//                try fileManager.removeItem(at: destinationURL)
//            } catch {}
            
            // Get list of apks
            let sourceURL = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("apks")
            
            var apkFiles: [URL] = []
            do {
                apkFiles = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: nil).filter{ $0.pathExtension == "apk" }
            } catch {}
            
            let temporaryApks = apkFiles.map { file in Apk(id: file.path, path: file.path, fileName: file.lastPathComponent) }
            DispatchQueue.main.async {
                ApkStore.sharedInstance.submit(newApks: temporaryApks)
            }
            
            do {
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // TODO: Handle exception
            }
            
            print("apks", apkFiles)
            
            let apks: [Apk] = apkFiles.map { file in
                let fileUnzipDirectory = destinationURL.appendingPathComponent(file.lastPathComponent)
                print("unzip", fileUnzipDirectory)
                // Unzip APK
//                do {
//                    try fileManager.createDirectory(at: fileUnzipDirectory, withIntermediateDirectories: true, attributes: nil)
//                    try fileManager.unzipItem(at: file, to: fileUnzipDirectory)
//                } catch {
//                    print("Extraction of ZIP archive failed with error:\(error)")
//                }
                
                // Decode AXML
                let task = Process()
                task.executableURL = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("platform-tools/AxmlPrinter")
                task.arguments = [fileUnzipDirectory.appendingPathComponent("AndroidManifest.xml").path]
                let outputPipe = Pipe()
                task.standardOutput = outputPipe
                do {
                    try task.run()
                } catch {
                    print("Parsing xml failed with error:\(error)")
                }
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: outputData, as: UTF8.self)
                
                print("output", output)
                
                // Parse XML
                let xml = SWXMLHash.parse(output)
                
                guard let package = xml["manifest"].element?.attribute(by: "package")?.text else { return nil; }
                guard let label = xml["manifest"]["application"].element?.attribute(by: "android:label")?.text else { return nil; }
                
                // Get Icon
                var iconUrl: URL?
                do {
                    let iconDirectory = fileUnzipDirectory.appendingPathComponent("res/mipmap-hdpi-v4/")
                    let fileURLs = try fileManager.contentsOfDirectory(at: iconDirectory, includingPropertiesForKeys: nil)
                    iconUrl = fileURLs.first
                } catch {}
                
                let apk = Apk(id: package, path: file.path, fileName: file.lastPathComponent, package: package, label: label, iconUrl: iconUrl)
                
                return apk
            }.compactMap { $0 }
            
            DispatchQueue.main.async {
                ApkStore.sharedInstance.submit(newApks: apks)
                ApkStore.sharedInstance.stopLoad()
            }
        }
    }
}
