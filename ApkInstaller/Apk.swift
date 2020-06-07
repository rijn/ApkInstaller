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

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

extension Data {
    init(reading input: InputStream) throws {
        self.init()
        input.open()
        defer {
            input.close()
        }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read < 0 {
                //Stream error occured
                throw input.streamError!
            } else if read == 0 {
                //EOF
                break
            }
            self.append(buffer, count: read)
        }
    }
}

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
            #if !DEBUG
            do {
                try fileManager.removeItem(at: destinationURL)
            } catch {}
            #endif
            
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

            let apks: [Apk] = apkFiles.map { file in
                let fileUnzipDirectory = destinationURL.appendingPathComponent(file.lastPathComponent)
                // Unzip APK
                #if !DEBUG
                do {
                    try fileManager.createDirectory(at: fileUnzipDirectory, withIntermediateDirectories: true, attributes: nil)
                    try fileManager.unzipItem(at: file, to: fileUnzipDirectory)
                } catch {
                    print("Extraction of ZIP archive failed with error:\(error)")
                }
                #endif
                
                // Decode AXML
                var output: String?
                do {
                    let data = NSData(contentsOf: fileUnzipDirectory.appendingPathComponent("AndroidManifest.xml"))
                    if (data == nil) {
                        throw "Empty AndroidManifest.xml"
                    }
                    var outputBuffer: UnsafeMutablePointer<Int8>? = nil
                    var outputSize: Int = 0
                    AxmlToXml(&outputBuffer, &outputSize, data?.bytes.assumingMemoryBound(to: Int8.self), data!.length)
                    let outputData = NSData(bytes: outputBuffer, length: outputSize)
                    output = String(data: outputData as Data, encoding: .utf8)
                } catch {
                    print("Parsing AXML failed with error: \(error)")
                }
                guard output != nil else { return nil; }
                
                // Parse XML
                let xml = SWXMLHash.parse(output!)
                
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
