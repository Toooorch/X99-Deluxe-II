/*
 * main.swift
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

let settings = CloverSettings()
let findData = Data.init(bytes: [0x4e, 0x56, 0x44, 0x41, 0x52, 0x65, 0x71, 0x75, 0x69, 0x72, 0x65, 0x64, 0x4f, 0x53, 0x00])
let replaceData = Data.init(bytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
let error = settings?.kextsToPatch(name: "NVDAStartupWeb", find: findData, replace: replaceData, comment: "webdriver.sh: Disable NVIDIA Required OS", disabled: false)
if let result: Bool = error, result == true {
        exit(0)
} else {
        exit(1)
}
