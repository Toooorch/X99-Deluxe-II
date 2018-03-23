/*
 * DiskUtil.swift
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

class DiskUtil: NSObject {
        
        let diskUtilPath = "/usr/sbin/diskutil"
        
        @discardableResult func shell(launchPath: String, arguments: [String] = []) -> (String? , Int32) {
                let task = Process()
                task.launchPath = launchPath
                task.arguments = arguments
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                task.launch()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                task.waitUntilExit()
                return (output, task.terminationStatus)
        }
        
        @discardableResult func mount(bsdName: String) -> Bool {
                let error = shell(launchPath: diskUtilPath, arguments: ["mount", bsdName]).1
                if error == 0 {
                        return true
                } else {
                        return false
                }
        }
        
}
