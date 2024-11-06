import UIKit
import FirebaseAuth

class EditTextView: UIViewController {
    @IBOutlet weak var scriptTextView: UITextView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    
    private var sessionStore = SessionStore()
    var script: Script?
    var isNewScript: Bool = false
    weak var delegate: EditScriptDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let script = script {
            scriptTextView.text = script.content
            titleTextField.text = script.title
        } else {
            scriptTextView.text = ""
            titleTextField.text = ""
            setTitleTextFieldPlaceholder()
        }
    }
    
    private func setTitleTextFieldPlaceholder() {
        let placeholderText = "Enter Title"
        let placeholderColor = UIColor.white
        titleTextField.attributedPlaceholder = NSAttributedString(
            string: placeholderText,
            attributes: [NSAttributedString.Key.foregroundColor: placeholderColor]
        )
    }
    
    @IBAction func saveScript(_ sender: UIButton) {
        guard let title = titleTextField.text, !title.isEmpty,
              let content = scriptTextView.text, !content.isEmpty else {
            showAlert(title: "Error", message: "Title and content cannot be empty")
            return
        }
        
        let newScript = Script(title: title, content: content, lastModified: Date())
        
        if sessionStore.isSignedIn {
            checkForDuplicateTitleInFirebase(title: title) { [weak self] exists in
                if exists {
                    self?.showDuplicateTitleAlert()
                } else {
                    self?.handleFirebaseSave(newScript)
                }
            }
        } else {
            checkForDuplicateTitleInUserDefaults(title: title) { [weak self] exists in
                if exists {
                    self?.showDuplicateTitleAlert()
                } else {
                    self?.handleUserDefaultsSave(newScript)
                }
            }
        }
    }

    private func checkForDuplicateTitleInFirebase(title: String, completion: @escaping (Bool) -> Void) {
        FirebaseManager.shared.loadScripts { [weak self] scripts, error in
            if let scripts = scripts {
                if let existingScript = self?.script, existingScript.title == title {
                    completion(false)
                } else {
                    completion(scripts.contains { $0.title == title })
                }
            } else {
                completion(false)
            }
        }
    }

    private func checkForDuplicateTitleInUserDefaults(title: String, completion: @escaping (Bool) -> Void) {
        let scripts = UserDefaults.standard.loadScripts()
        if let existingScript = script, existingScript.title == title {
            completion(false)
        } else {
            completion(scripts.contains { $0.title == title })
        }
    }

    private func showDuplicateTitleAlert() {
        showAlert(title: "Duplicate Title", message: "A script with this title already exists. Please choose a different title.")
    }

    private func handleUserDefaultsSave(_ script: Script) {
        var scripts = UserDefaults.standard.loadScripts()
        if let index = scripts.firstIndex(where: { $0.title == script.title }) {
            scripts[index] = script
        } else {
            scripts.append(script)
        }
        UserDefaults.standard.saveScripts(scripts)
        UserDefaults.standard.saveLastOpenedScript(script)
        delegate?.updateScript(script)
        dismiss(animated: true, completion: nil)
    }

    private func handleFirebaseSave(_ script: Script) {
        var newScript = script
        newScript.lastModified = Date() // Update the timestamp
        FirebaseManager.shared.saveScript(newScript) { [weak self] error in
            if let error = error {
                print("Error saving script: \(error)")
            } else {
                print("Script saved to Firebase")
                self?.delegate?.updateScript(newScript)
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func discardAndGoBackTapped(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true) // Resign first responder when touching outside the text view
    }

    @IBAction func savedScriptsTapped(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let savedScriptsVC = storyboard.instantiateViewController(withIdentifier: "SavedScriptsViewController") as? SavedScriptsViewController {
            present(savedScriptsVC, animated: true, completion: nil)
        }
    }
}
