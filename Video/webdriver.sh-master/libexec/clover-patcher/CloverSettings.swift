/*
 * CloverSettings.swift
 *
 * webdriver.sh - bash script for managing Nvidia's web drivers
 * Copyright © 2018 vulgo
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

import Foundation

class CloverSettings {
        
        let session: DASession = DASessionCreate(kCFAllocatorDefault)!
        let fileManager = FileManager()
        var bootLogData: Data?
        var bootLog: String?
        var cloverUuid: String?
        var cloverBsdName: String?
        var cloverVolumeUrl: URL?
        var cloverSettingsUrl: URL?
        
        public struct CloverKextPatch {
                var Name: String
                var Find: Data
                var Replace: Data
                var Comment: String
                var Disabled: Bool
                init(name: String, find: Data, replace: Data, comment: String, disabled: Bool) {
                        Name = name
                        Find = find
                        Replace = replace
                        Comment = comment
                        Disabled = disabled
                }
        }
        
        enum CloverKeys {
                case KernelAndKextPatches
                case KextsToPatch
                case Find
                case Replace
                case Comment
                case Name
                case Disabled
                var string: String {
                        switch self {
                        case .KernelAndKextPatches:
                                return "KernelAndKextPatches"
                        case .KextsToPatch:
                                return "KextsToPatch"
                        case .Find:
                                return "Find"
                        case .Replace:
                                return "Replace"
                        case .Comment:
                                return "Comment"
                        case .Name:
                                return "Name"
                        case .Disabled:
                                return "Disabled"
                        }
                }
        }
        
        init?() {
                /* Get Clover partition */
                let platform = RegistryEntry.init(fromPath: "IODeviceTree:/efi/platform")
                bootLogData = platform.getDataValue(forProperty: "boot-log")
                if bootLogData != nil {
                        bootLog = NSString.init(data: bootLogData!, encoding: String.Encoding.utf8.rawValue) as String?
                }
                var components: [String]?
                if bootLog != nil {
                        let lines: [String] = bootLog!.lines
                        for line in lines {
                                if line.contains("SelfDevicePath") {
                                        components = line.split{$0 == ","}.map(String.init)
                                }
                        }
                }
                if components != nil {
                        for component in components! {
                                if let uuid = NSUUID.init(uuidString: component) {
                                        cloverUuid = uuid.uuidString
                                }
                        }
                }
                /* Get Clover BSD Name */
                if let efiUuid: String = cloverUuid {
                        let efiPartitions = RegistryEntry.init(iteratorFromMatchingDictionary: IOServiceNameMatching("EFI System Partition"))
                        while cloverBsdName == nil {
                                efiPartitions.registryEntry = IOIteratorNext(efiPartitions.iterator)
                                if IORegistryEntryCopyPath(efiPartitions.registryEntry, kIOServicePlane) == nil {
                                        break
                                }
                                let uuid = efiPartitions.getStringValue(forProperty: "UUID")
                                if uuid == efiUuid {
                                        cloverBsdName = efiPartitions.getStringValue(forProperty: "BSD Name")
                                }
                        }
                }
                guard cloverBsdName != nil else {
                        print("Clover BSD name should no longer be nil")
                        return nil
                }
                cloverVolumeUrl = volumeUrl(forBsdName: cloverBsdName!)
                if cloverVolumeUrl == nil {
                        /* Try to mount partition */
                        let diskUtil = DiskUtil()
                        for _ in 1...5 {
                                diskUtil.mount(bsdName: cloverBsdName!)
                                cloverVolumeUrl = volumeUrl(forBsdName: cloverBsdName!)
                                if cloverVolumeUrl != nil {
                                        break
                                }
                                sleep(3)
                        }
                }
                guard cloverVolumeUrl != nil else {
                        print("Clover volume URL should no longer be nil")
                        return nil
                }
                cloverSettingsUrl = appendTo(url: cloverVolumeUrl!, directories: "EFI", "CLOVER", fileName: "config", ext: "plist")
                guard fileManager.fileExists(atPath: cloverSettingsUrl!.path) else {
                        print("Failed to find Clover settings file")
                        return nil
                }
        }
        
        func appendTo(url base: URL, directories: String..., fileName: String? = nil, ext: String? = nil) -> URL {
                var url: URL = base
                for directory: String in directories {
                        url = url.appendingPathComponent(directory, isDirectory: true)
                }
                if let fileName: String = fileName {
                        url = url.appendingPathComponent(fileName)
                }
                if let ext: String = ext {
                        url = url.appendingPathExtension(ext)
                }
                return url
        }
        
        func volumeUrl(forBsdName bsdName: String) -> URL? {
                var volumeUrl: URL?
                if let disk: DADisk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName) {
                        if let description: [String: Any] = DADiskCopyDescription(disk) as? Dictionary {
                                if let url = description["DAVolumePath"] as! URL? {
                                        volumeUrl = url
                                }
                        }
                }
                return volumeUrl
        }
        
        func kextsToPatch(name: String, find: Data, replace: Data, comment: String, disabled: Bool) -> Bool {
                let patchDict: [String: Any] = [CloverKeys.Name.string: name, CloverKeys.Find.string: find, CloverKeys.Replace.string: replace, CloverKeys.Comment.string: comment, CloverKeys.Disabled.string: disabled]
                guard cloverSettingsUrl != nil else {
                        return false
                }
                /* Read config.plist */
                let settingsDictionary = NSMutableDictionary.init(contentsOf: cloverSettingsUrl!)
                var kernelAndKextPatches: NSMutableDictionary?
                var kextsToPatch: NSMutableArray?
                if let dict = settingsDictionary?[CloverKeys.KernelAndKextPatches.string] as? NSMutableDictionary {
                        if let array = dict[CloverKeys.KextsToPatch.string] as? NSMutableArray {
                                kernelAndKextPatches = dict
                                kextsToPatch = array
                        } else {
                                kernelAndKextPatches = dict
                                kextsToPatch = nil
                        }
                } else {
                        kernelAndKextPatches = nil
                        kextsToPatch = nil
                }
                if kernelAndKextPatches == nil {
                        /* Create new KernelAndKextPatches dict, new KextsToPatch array */
                        kernelAndKextPatches = NSMutableDictionary.init()
                        kextsToPatch = NSMutableArray.init(objects: patchDict)
                        kernelAndKextPatches?.addEntries(from: [CloverKeys.KextsToPatch.string: kextsToPatch!])
                        settingsDictionary?.addEntries(from: [CloverKeys.KernelAndKextPatches.string: kernelAndKextPatches!])
                } else {
                        if kextsToPatch == nil {
                                /* Add new KextsToPatch array to existing KernelAndKextPatches dict */
                                kextsToPatch = NSMutableArray.init(objects: patchDict)
                                kernelAndKextPatches?.addEntries(from: [CloverKeys.KextsToPatch.string: kextsToPatch!])
                        } else {
                                /* Merge into existing, try to remove duplicates */
                                let duplicates: IndexSet? = kextsToPatch?.indexesOfObjects(options: [], passingTest: { (constraint, idx, stop) in
                                        if let dict = constraint as? NSDictionary {
                                                let test: String? = dict[CloverKeys.Comment.string] as? String
                                                if let commentString: String = test {
                                                        if commentString.contains("webdriver.sh: ") {
                                                                return true
                                                        }
                                                }
                                                if (dict[CloverKeys.Find.string] as? Data == find && dict[CloverKeys.Name.string] as? String == name) {
                                                        return true
                                                }
                                        }
                                        return false
                                })
                                if duplicates != nil {
                                        kextsToPatch?.removeObjects(at: duplicates!)
                                }
                                /* Add the patch */
                                kextsToPatch?.add(patchDict)
                        }
                }
                /* Write config.plist */
                let cloverSettingsBackupUrl = appendTo(url: cloverVolumeUrl!, directories: "EFI", "CLOVER", fileName: "config-backup", ext: "~plist")
                var propertyList: Data
                do {
                        propertyList = try PropertyListSerialization.data(fromPropertyList: settingsDictionary!, format: .xml, options: 0)
                } catch {
                        let errorDescription = error.localizedDescription
                        print(errorDescription)
                        return false
                }
                do {
                        if fileManager.fileExists(atPath: cloverSettingsBackupUrl.path) {
                                try fileManager.removeItem(atPath: cloverSettingsBackupUrl.path)
                        }
                        try fileManager.copyItem(at: cloverSettingsUrl!, to: cloverSettingsBackupUrl)
                        try propertyList.write(to: cloverSettingsUrl!)
                } catch let error as NSError {
                        let errorDescription = error.localizedDescription
                        print(errorDescription)
                        return false
                }
                return true
        }   
}
