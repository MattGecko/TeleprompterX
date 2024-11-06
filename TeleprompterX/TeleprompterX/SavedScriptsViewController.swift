import UIKit
import FirebaseAuth

class SavedScriptsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var syncFromFirebaseButton: UIButton!
    @IBOutlet weak var syncToFirebaseButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!

    private var sessionStore = SessionStore()
    var scripts: [Script] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        updateUI()
        loadScripts()
    }

    private func updateUI() {
        let isSignedIn = sessionStore.isSignedIn
        syncFromFirebaseButton.isEnabled = isSignedIn
        syncToFirebaseButton.isEnabled = isSignedIn
        signInButton.setTitle(isSignedIn ? "Sign Out" : "Sign In", for: .normal)
    }

    private func loadScripts() {
        if sessionStore.isSignedIn {
            FirebaseManager.shared.loadScripts { [weak self] scripts, error in
                if let error = error {
                    print("Error loading scripts: \(error)")
                    return
                }
                self?.scripts = scripts ?? []
                self?.tableView.reloadData()
            }
        } else {
            scripts = UserDefaults.standard.loadScripts()
            tableView.reloadData()
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @IBAction func signInTapped(_ sender: UIButton) {
        if sessionStore.isSignedIn {
            do {
                try Auth.auth().signOut()
                sessionStore.isSignedIn = false
                updateUI()
                loadScripts()
            } catch let signOutError as NSError {
                print("Error signing out: %@", signOutError)
                showAlert(title: "Sign Out Error", message: signOutError.localizedDescription)
            }
        } else {
            let alert = UIAlertController(title: "Sign In", message: "Enter your email and password to sign in", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.placeholder = "Email"
            }
            alert.addTextField { (textField) in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            }
            let signInAction = UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
                guard let email = alert.textFields?[0].text, let password = alert.textFields?[1].text else { return }
                Auth.auth().signIn(withEmail: email, password: password) { (authResult, error) in
                    if let error = error {
                        print("Error signing in: \(error)")
                        self?.showAlert(title: "Sign In Error", message: error.localizedDescription)
                        return
                    }
                    self?.sessionStore.isSignedIn = true
                    self?.updateUI()
                    self?.loadScripts()
                }
            }
            alert.addAction(signInAction)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }


    @IBAction func syncFromFirebaseTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Sync from Cloud", message: "This will overwrite scripts on your device with your scripts from Cloud. Do you want to continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            FirebaseManager.shared.syncFromFirebaseToUserDefaults { error in
                if let error = error {
                    print("Error syncing from Firebase: \(error)")
                } else {
                    self?.loadScripts()
                    print("Successfully synced from Firebase to UserDefaults")
                }
            }
        })
        present(alert, animated: true, completion: nil)
    }

    @IBAction func syncToFirebaseTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Sync to Cloud", message: "This will overwrite your Cloud scripts with the scripts on your device. Do you want to continue?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            FirebaseManager.shared.syncFromUserDefaultsToFirebase { error in
                if let error = error {
                    print("Error syncing to Firebase: \(error)")
                } else {
                    print("Successfully synced from UserDefaults to Firebase")
                }
            }
        })
        present(alert, animated: true, completion: nil)
    }
}

extension SavedScriptsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scripts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScriptCell", for: indexPath)
        let script = scripts[indexPath.row]
        cell.textLabel?.text = script.title
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let script = scripts[indexPath.row]
        if let presentingVC = self.presentingViewController as? EditTextView {
            presentingVC.script = script
            presentingVC.viewDidLoad() // Refresh the EditTextView with the selected script
            self.dismiss(animated: true, completion: nil)
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let script = scripts[indexPath.row]
            scripts.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            if sessionStore.isSignedIn {
                FirebaseManager.shared.deleteScript(script) { error in
                    if let error = error {
                        print("Error deleting script: \(error)")
                    }
                }
            } else {
                var savedScripts = UserDefaults.standard.loadScripts()
                if let index = savedScripts.firstIndex(where: { $0.title == script.title }) {
                    savedScripts.remove(at: index)
                }
                UserDefaults.standard.saveScripts(savedScripts)
            }
        }
    }
}
