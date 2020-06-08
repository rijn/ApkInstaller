//
//  Apk.swift
//  MilanInstaller
//
//  Created by Yuanzhe Bian on 6/5/20.
//  Copyright © 2020 rijn. All rights reserved.
//

import Foundation

extension String {
    func matchingStrings(regex: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        return results.map { result in
            (0..<result.numberOfRanges).map {
                result.range(at: $0).location != NSNotFound
                    ? nsString.substring(with: result.range(at: $0))
                    : ""
            }
        }
    }
}

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return index >= startIndex && index < endIndex ? self[index] : nil
    }
}

enum DeviceInstallState {
    case standBy
    case pending
    case installing
    case installed
    case failed
}

struct Device: Hashable, Identifiable {
    var id: String
    
    var label: String?
    
    var state: DeviceInstallState = .standBy
}

final class DeviceStore: ObservableObject {
    static let sharedInstance = DeviceStore()
    
    @Published var devices: [Device] = []
    @Published var selectedDevices: Set<String> = []
    
    @Published var isRefreshing: Bool = false
    @Published var isBusy: Bool = false
    
    func submit(newDevices: [Device]) {
        devices = newDevices
    }
    
    func updateDeviceById(deviceId: String, updater: (Device) -> Device) {
        if let index = devices.firstIndex(where: { $0.id == deviceId }) {
            devices[index] = updater(devices[index])
        }
    }
    
    func updateDevice(updater: (Device) -> Device, filter: (Device) -> Bool = { (_: Any) in true }) {
        devices = devices.map { filter($0) ? updater($0) : $0 }
    }
    
    func getDeviceById(deviceId: String) -> Device? {
        return devices.first(where: { $0.id == deviceId })
    }
    
    func startRefresh() {
        isRefreshing = true
    }
    
    func stopRefresh() {
        isRefreshing = false
    }
    
    func startLoad() {
        isBusy = true
    }
    
    func stopLoad() {
        isBusy = false
    }
}

final class DeviceService {
    
    static private func executeAdbCommand(arguments: [String]) -> (output: String, error: String) {
        // Decode AXML
        let task = Process()
        task.executableURL = Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("adb")
        task.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Execute with error: \(error)")
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)
        
        return (output, error)
    }
    
    static private func fetchDevices() -> [Device] {
        var deviceListResult: [String] = executeAdbCommand(arguments: ["devices", "-l"]).output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
        deviceListResult.removeFirst()
        return deviceListResult
            .map {
                let components = $0.components(separatedBy: " ").filter { !$0.isEmpty }
                return Device(id: components.first!, label: components.first(where: { $0.contains("product:") })?.components(separatedBy: ":").last)
        }
    }
    
    static func refresh() {
        DeviceStore.sharedInstance.startRefresh()
        DeviceStore.sharedInstance.startLoad()
        
        DispatchQueue.global(qos: .background).async {
            let devices = fetchDevices()
            
            DispatchQueue.main.async {
                DeviceStore.sharedInstance.submit(newDevices: devices)
                DeviceStore.sharedInstance.stopRefresh()
                DeviceStore.sharedInstance.stopLoad()
            }
        }
    }
    
    static func install(force: Bool) {
        DeviceStore.sharedInstance.startLoad()
        
        DeviceStore.sharedInstance.updateDevice(updater: {
            var device = $0
            device.state = .standBy
            return device
        })
        
        DeviceStore.sharedInstance.updateDevice(updater: {
            var device = $0
            device.state = .pending
            return device
        }, filter: { DeviceStore.sharedInstance.selectedDevices.contains($0.id) })
        
        DispatchQueue.global(qos: .background).async {
            executeAdbCommand(arguments: ["kill-server"])
            executeAdbCommand(arguments: ["start-server"])
            
            DeviceStore.sharedInstance.selectedDevices.forEach { selectedDeviceId in
                DispatchQueue.main.async {
                    DeviceStore.sharedInstance.updateDeviceById(deviceId: selectedDeviceId) {
                        var device = $0
                        device.state = .installing
                        return device
                    }
                }
                
                var didInstallSucceed: Bool = true
                
                ApkStore.sharedInstance.apks
                    .filter { ApkStore.sharedInstance.selectedApks.contains($0.id) }
                    .forEach {
                        if (force && $0.package != nil) {
                            let result = executeAdbCommand(arguments: ["-s", selectedDeviceId, "uninstall", $0.package!])
                            print(result)
                        }
                        let (output, error) = executeAdbCommand(arguments: ["-s", selectedDeviceId, "install", $0.path])
                        if (error.contains("failed to install")) {
                            didInstallSucceed = false
                            print("Failed to install", output, error)
                        }
                }
                
                DispatchQueue.main.async {
                    DeviceStore.sharedInstance.updateDeviceById(deviceId: selectedDeviceId) {
                        var device = $0
                        device.state = didInstallSucceed ? .installed : .failed
                        return device
                    }
                }
            }
            
            DispatchQueue.main.async {
                DeviceStore.sharedInstance.stopLoad()
            }
        }
    }
}
