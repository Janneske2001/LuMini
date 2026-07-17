//
//  UpdateChecker.swift
//  LuMini
//
//  Created by Jannes ‎ on 16/07/2026.
//

import Foundation
import Combine
import SwiftUI

class UpdateChecker: ObservableObject {
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    
    @AppStorage("autoCheckForUpdates") var autoCheckForUpdates = true
    @AppStorage("lastUpdateCheckDate") private var lastUpdateCheckDate: Date?
    @AppStorage("updateAvailableCache") private var updateAvailableCache: Bool = false
    @AppStorage("latestVersionCache") private var latestVersionCache: String = ""
    
    private let repoURL = URL(string: "https://api.github.com/repos/Janneske2001/LuMini/releases/latest")!
    
    init() {
        // Load cached state
        updateAvailable = updateAvailableCache
        latestVersion = latestVersionCache
    }
    
    func performCheck(showResult: Bool = false, completion: ((Bool, String?) -> Void)? = nil) {
        guard autoCheckForUpdates else {
            // If auto-check is off, don't do anything
            completion?(false, nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: repoURL) { [weak self] data, _, error in
            guard let self = self else { return }
            var newVersionAvailable = false
            var newVersion = ""
            
            defer {
                DispatchQueue.main.async {
                    self.updateAvailable = newVersionAvailable
                    self.latestVersion = newVersion
                    // Cache
                    self.updateAvailableCache = newVersionAvailable
                    self.latestVersionCache = newVersion
                    if showResult {
                        completion?(newVersionAvailable, newVersion)
                    } else {
                        completion?(false, nil)
                    }
                }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                print("Update check failed")
                return
            }
            
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            newVersionAvailable = tagName > currentVersion
            newVersion = tagName
        }
        task.resume()
    }
    
    func checkForUpdatesManually(completion: @escaping (Bool, String?) -> Void) {
        // Force a check regardless of autoCheckForUpdates
        let task = URLSession.shared.dataTask(with: repoURL) { [weak self] data, _, error in
            guard let self = self else { return }
            var newVersionAvailable = false
            var newVersion = ""
            
            defer {
                DispatchQueue.main.async {
                    self.updateAvailable = newVersionAvailable
                    self.latestVersion = newVersion
                    self.updateAvailableCache = newVersionAvailable
                    self.latestVersionCache = newVersion
                    completion(newVersionAvailable, newVersion)
                }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                print("Manual update check failed")
                return
            }
            
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
            newVersionAvailable = tagName > currentVersion
            newVersion = tagName
        }
        task.resume()
    }
}
