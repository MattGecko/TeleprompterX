import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore

class FirebaseManager {
    static let shared = FirebaseManager()
    
    private init() {}
    
    var auth: Auth {
        return Auth.auth()
    }
    
    private var db: Firestore {
        return Firestore.firestore()
    }
    
    func deleteAllScripts(completion: @escaping (Error?) -> Void) {
            let userId = Auth.auth().currentUser?.uid
            let scriptsRef = Firestore.firestore().collection("users").document(userId!).collection("scripts")
            
            scriptsRef.getDocuments { (querySnapshot, error) in
                if let error = error {
                    completion(error)
                    return
                }
                
                let batch = Firestore.firestore().batch()
                querySnapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { batchError in
                    completion(batchError)
                }
            }
        }
    
    func saveScript(_ script: Script, completion: @escaping (Error?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            completion(NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
            return
        }
        
        db.collection("users").document(userId).collection("scripts").document(script.title).setData([
            "title": script.title,
            "content": script.content,
            "lastModified": script.lastModified
        ]) { error in
            completion(error)
        }
    }

    func loadScripts(completion: @escaping ([Script]?, Error?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            completion(nil, NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
            return
        }
        
        db.collection("users").document(userId).collection("scripts").getDocuments { snapshot, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            var scripts = [Script]()
            snapshot?.documents.forEach { document in
                let data = document.data()
                if let title = data["title"] as? String,
                   let content = data["content"] as? String,
                   let timestamp = data["lastModified"] as? Timestamp {
                    let lastModified = timestamp.dateValue()
                    scripts.append(Script(title: title, content: content, lastModified: lastModified))
                }
            }
            completion(scripts, nil)
        }
    }

    
    
    func saveScripts(_ scripts: [Script], completion: @escaping (Error?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            completion(NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
            return
        }
        
        let batch = db.batch()
        let userScriptsRef = db.collection("users").document(userId).collection("scripts")
        
        scripts.forEach { script in
            let scriptRef = userScriptsRef.document(script.title)
            batch.setData([
                "title": script.title,
                "content": script.content
            ], forDocument: scriptRef)
        }
        
        batch.commit { error in
            completion(error)
        }
    }

    
    
    func deleteScript(_ script: Script, completion: @escaping (Error?) -> Void) {
            guard let userId = auth.currentUser?.uid else {
                completion(NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
                return
            }
            
            db.collection("users").document(userId).collection("scripts").document(script.title).delete { error in
                completion(error)
            }
        }
    
  
    
    func syncFromFirebaseToUserDefaults(completion: @escaping (Error?) -> Void) {
        loadScripts { scripts, error in
            if let error = error {
                completion(error)
                return
            }
            
            if let scripts = scripts {
                UserDefaults.standard.saveScripts(scripts)
                if let lastOpenedScript = scripts.last {
                    UserDefaults.standard.saveLastOpenedScript(lastOpenedScript)
                }
            }
            completion(nil)
        }
    }
    
    func syncFromUserDefaultsToFirebase(completion: @escaping (Error?) -> Void) {
        guard let userId = auth.currentUser?.uid else {
            completion(NSError(domain: "FirebaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
            return
        }
        
        let scripts = UserDefaults.standard.loadScripts()
        let batch = db.batch()
        
        let userScriptsRef = db.collection("users").document(userId).collection("scripts")
        scripts.forEach { script in
            let scriptRef = userScriptsRef.document(script.title)
            batch.setData([
                "title": script.title,
                "content": script.content
            ], forDocument: scriptRef)
        }
        
        batch.commit { error in
            completion(error)
        }
    }
}
