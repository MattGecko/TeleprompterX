import Foundation

extension UserDefaults {
    private enum Keys {
        static let scripts = "scripts"
        static let videoCaptionsEnabled = "VideoCaptionsEnabled"
    }

    func saveScripts(_ scripts: [Script]) {
        let encoder = JSONEncoder()
        if let encodedScripts = try? encoder.encode(scripts) {
            set(encodedScripts, forKey: Keys.scripts)
            synchronize()
        }
    }
    
  

    var videoCaptionsEnabled: Bool {
            get {
                return bool(forKey: Keys.videoCaptionsEnabled)
            }
            set {
                set(newValue, forKey: Keys.videoCaptionsEnabled)
            }
        }

    func loadScripts() -> [Script] {
        if let savedScriptsData = data(forKey: Keys.scripts) {
            let decoder = JSONDecoder()
            if let loadedScripts = try? decoder.decode([Script].self, from: savedScriptsData) {
                return loadedScripts
            }
        }
        return []
    }

    func saveLastOpenedScript(_ script: Script) {
        let encoder = JSONEncoder()
        if let encodedScript = try? encoder.encode(script) {
            set(encodedScript, forKey: "lastOpenedScript")
            synchronize()
        }
    }

    func loadLastOpenedScript() -> Script? {
        if let savedScriptData = data(forKey: "lastOpenedScript") {
            let decoder = JSONDecoder()
            if let loadedScript = try? decoder.decode(Script.self, from: savedScriptData) {
                return loadedScript
            }
        }
        return nil
    }
}
