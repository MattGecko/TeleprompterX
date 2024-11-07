import UIKit
import SwiftUI
import RevenueCatUI
import XMLCoder
import FirebaseAuth
import UniformTypeIdentifiers
import PDFKit
import ZIPFoundation
import RevenueCat
import FBSDKCoreKit
import GoogleMobileAds


class ScriptsCollectionViewController: UIViewController, PaywallViewControllerDelegate, SpecialOfferViewControllerDelegate {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var deleteAllBtn: UIButton!
    @IBOutlet weak var upgradeBtn: UIButton!
    private var bannerView: GADBannerView!

    private var sessionStore = SessionStore()
    var scripts: [Script] = []
    private var isEditingMode: Bool = false

    func didCompletePurchase() {
        // Handle any additional setup after purchase if needed
        checkPremiumStatusAndUpdateUI()
    }
    
    var importedScriptsCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: "ImportedScriptsCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ImportedScriptsCount")
        }
    }
    struct AdConfig: Decodable {
        let showBannerAd: Bool
        let showInterstitialAd: Bool
    }

    private var adConfig: AdConfig?

    func fetchAdConfig() {
        guard let url = URL(string: "https://mattcowlin.com/DougHasNoFriends/config.json") else {
            // Set default to show ads if URL is invalid
            adConfig = AdConfig(showBannerAd: true, showInterstitialAd: true)
            updateAdVisibility()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let data = data, error == nil {
                do {
                    self.adConfig = try JSONDecoder().decode(AdConfig.self, from: data)
                } catch {
                    print("Failed to parse ad config; using default values.")
                    self.adConfig = AdConfig(showBannerAd: true, showInterstitialAd: true)
                }
            } else {
                print("Failed to fetch ad config: \(error?.localizedDescription ?? "No error description")")
                // Set default to show ads if there was an error
                self.adConfig = AdConfig(showBannerAd: true, showInterstitialAd: true)
            }
            
            // Apply the configuration on the main thread
            DispatchQueue.main.async {
                self.updateAdVisibility()
            }
        }.resume()
    }
    
    func updateAdVisibility() {
        // Ensure that `adConfig` is available
        guard let adConfig = adConfig else {
            // Default to showing ads if config is unavailable
            bannerView.isHidden = false
            return
        }
        
        // Show or hide the banner ad based on the remote configuration and premium status
        checkPremiumStatusAndUpdateUI()
        
        // Update banner visibility based on the `showBannerAd` config value
        if adConfig.showBannerAd {
            bannerView.isHidden = false
            bannerView.load(GADRequest())  // Ensure the ad is loaded when it should be shown
        } else {
            bannerView.isHidden = true
        }
    }

    
    static var shouldPresentSpecialOffer: Bool = false
    
    func presentSpecialOffer() {
        print("Present Special Offer Called")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let specialOfferVC = storyboard.instantiateViewController(withIdentifier: "SpecialOfferViewController") as? SpecialOfferViewController {
            specialOfferVC.delegate = self
            specialOfferVC.modalPresentationStyle = .pageSheet // Ensure modal presentation
            present(specialOfferVC, animated: true, completion: nil)
        }
    }

    func checkPremiumStatusAndUpdateUI() {
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            
            if let customerInfo = customerInfo, error == nil {
                let isUpgraded = customerInfo.entitlements["Pro Upgrade"]?.isActive == true
                self.upgradeBtn.isHidden = isUpgraded
                
                // Update banner visibility based on premium status and remote config
                if let adConfig = self.adConfig {
                    self.bannerView.isHidden = isUpgraded || !adConfig.showBannerAd
                } else {
                    self.bannerView.isHidden = isUpgraded
                }
            }
        }
    }


    
    func presentAuthentication() {
        if !sessionStore.isSignedIn {
            let authView = UIHostingController(rootView: AuthenticationView(completion: { [weak self] message in
                self?.handleAuthenticationCompletion(message: message)
            }).environmentObject(sessionStore))
            authView.modalPresentationStyle = .pageSheet
            if let sheet = authView.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            present(authView, animated: true, completion: nil)
        }
    }

    private func handleAuthenticationCompletion(message: String?) {
        dismiss(animated: true, completion: {
            if let message = message {
                self.presentAlert(title: "Authentication", message: message) { [weak self] in
                    // Present the paywall after the alert is dismissed
                    self?.displayPaywall()
                }
            } else {
                // Successfully signed in
                self.loadScripts()
                self.collectionView.reloadData() // Reload the collection view
            }
        })
    }
    



func presentAlert(title: String, message: String, completion: @escaping () -> Void) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
        completion()
    }
    alertController.addAction(okAction)
    present(alertController, animated: true, completion: nil)
}

    func presentSignOutAlert() {
        let alertController = UIAlertController(title: "Signed Out", message: "You have been signed out.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // Do nothing
            print("Signed out")
        }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            isEditingMode = true
            collectionView.visibleCells.forEach { cell in
                if let scriptCell = cell as? ScriptCell {
                    scriptCell.startWobble()
                }
            }
            deleteAllBtn.isHidden = false // Show delete all button
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        if isEditingMode {
            isEditingMode = false
            collectionView.visibleCells.forEach { cell in
                if let scriptCell = cell as? ScriptCell {
                    scriptCell.stopWobble()
                }
            }
            deleteAllBtn.isHidden = true // Hide delete all button
        }
    }

    @IBOutlet weak var myBarButtonItem: UIBarButtonItem!

    @objc func handleSignUpNotification() {
         // Perform actions needed after sign up
         displayPaywall()
     }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Fetch the ad configuration remotely
           fetchAdConfig()

           // Initialize and configure the banner ad (as before)
           bannerView = GADBannerView(adSize: GADAdSizeBanner)
        //REAL KEY ca-app-pub-3785918208569837/5811885489
        
//        TEST KEY ca-app-pub-3940256099942544/2934735716
        
           bannerView.adUnitID = "ca-app-pub-3785918208569837/5811885489"
           bannerView.rootViewController = self
           bannerView.delegate = self
           bannerView.isHidden = true
           view.addSubview(bannerView)
           bannerView.translatesAutoresizingMaskIntoConstraints = false
           NSLayoutConstraint.activate([
               bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
               bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
               bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
               bannerView.heightAnchor.constraint(equalToConstant: 50)
           ])
           bannerView.load(GADRequest())
        // Add observer for didSignUp notification
        NotificationCenter.default.addObserver(self, selector: #selector(handleSignUpNotification), name: .didSignUp, object: nil)
        // Log a registration completion event
        AppEvents.shared.logEvent(.completedRegistration)
        if ScriptsCollectionViewController.shouldPresentSpecialOffer {
                    presentSpecialOffer()
                    ScriptsCollectionViewController.shouldPresentSpecialOffer = false
                }
      
        deleteAllBtn.isHidden = true
            view.addSubview(deleteAllBtn) // Add button to the view hierarchy
            deleteAllBtn.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                deleteAllBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                deleteAllBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                deleteAllBtn.widthAnchor.constraint(equalToConstant: 200),
                deleteAllBtn.heightAnchor.constraint(equalToConstant: 50)
            ])
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPressGesture)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.cancelsTouchesInView = false // Allow touches to be passed through to the collection view
        collectionView.addGestureRecognizer(tapGesture)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true // Enable drag interaction
        if let toggleButton = self.navigationItem.rightBarButtonItem {
                toggleButton.target = self
                toggleButton.action = #selector(toggleAuthentication(_:))
            }
        checkPremiumStatus() 
        presentAuthentication()
        checkAndLoadDefaultScript() // Check and load default script if necessary
    }
    
    deinit {
        collectionView.dataSource = nil
        collectionView.delegate = nil
        collectionView.dragDelegate = nil
        collectionView.dropDelegate = nil
        print("ScriptsCollectionViewController deinitialized")
    }
    
    func checkPremiumStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let customerInfo = customerInfo, error == nil {
                if customerInfo.entitlements.all["Pro Upgrade"]?.isActive == true {
                    print("Customer has upgraded")
                    self.upgradeBtn.isHidden = true
                    // Handle any initial setup if needed
                } else {
                    print("Customer has NOT upgraded")
                    self.upgradeBtn.isHidden = false
                    if UserDefaults.standard.bool(forKey: "hasLaunchedOnce") == false {
                        self.displayPaywall()
                        UserDefaults.standard.set(true, forKey: "hasLaunchedOnce")
                        UserDefaults.standard.synchronize()
                    }
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadScripts()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()
        checkPremiumStatusAndUpdateUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adjustCollectionViewInsets()
    }

    private func adjustCollectionViewInsets() {
        collectionView.contentInset.top = 0
    }
    
    @IBAction func callUpgrade (_ sender: UIButton) {
        displayPaywall()
    }

    private func checkAndLoadDefaultScript() {
        let hasOpenedBefore = UserDefaults.standard.bool(forKey: "hasOpenedBefore")
        if !hasOpenedBefore {
            loadDefaultScript()
            UserDefaults.standard.set(true, forKey: "hasOpenedBefore")
        }
    }

    private func loadDefaultScript() {
           let defaultScript = Script(
               title: "Default Script",
               content: "Here’s to the crazy ones, the misfits, the rebels, the troublemakers, the round pegs in the square holes… the ones who see things differently — they’re not fond of rules… You can quote them, disagree with them, glorify or vilify them, but the only thing you can’t do is ignore them because they change things… they push the human race forward, and while some may see them as the crazy ones, we see genius, because the ones who are crazy enough to think that they can change the world, are the ones who do.",
               lastModified: Date() // Current date and time
           )
           
           var scripts = UserDefaults.standard.loadScripts()
           scripts.append(defaultScript)
           UserDefaults.standard.saveScripts(scripts)
           UserDefaults.standard.saveLastOpenedScript(defaultScript)
       }

    private func sortScriptsByDate() {
        scripts.sort {
            if let firstDate = $0.lastModified as Date?, let secondDate = $1.lastModified as Date? {
                return firstDate > secondDate
            } else if $0.lastModified != nil {
                return true
            } else if $1.lastModified != nil {
                return false
            } else {
                return $0.title.lowercased() < $1.title.lowercased()
            }
        }
    }


    private func loadScripts() {
        if sessionStore.isSignedIn {
            // Load scripts from Firebase
            FirebaseManager.shared.loadScripts { [weak self] firebaseScripts, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error loading scripts from Firebase: \(error)")
                    return
                }

                // Load scripts from UserDefaults
                let userDefaultsScripts = UserDefaults.standard.loadScripts()

                // Merge scripts
                self.scripts = self.mergeScripts(firebaseScripts ?? [], with: userDefaultsScripts)

                // Sort scripts by date
                self.sortScriptsByDate()

                // Save merged scripts back to Firebase and UserDefaults
                self.saveMergedScripts(self.scripts)

                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                }
            }
        } else {
            // Load scripts from UserDefaults
            scripts = UserDefaults.standard.loadScripts()
            
            // Sort scripts by date
            sortScriptsByDate()
            
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        // Check the premium status and update the UI
        checkPremiumStatus()
        
        // Hide the upgrade button immediately if the user upgraded
        if customerInfo.entitlements.all["Pro Upgrade"]?.isActive == true {
            self.upgradeBtn.isHidden = true
        }
    }
    

    func showUpgradeAlert() {
        let alert = UIAlertController(title: "Premium Feature", message: "This is a premium feature. Would you like to upgrade?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.displayPaywall()
        })
        present(alert, animated: true, completion: nil)
    }

    private func mergeScripts(_ firebaseScripts: [Script], with userDefaultsScripts: [Script]) -> [Script] {
        var scriptDict = [String: Script]()
        
        // Add scripts from Firebase to dictionary
        for script in firebaseScripts {
            scriptDict[script.title] = script
        }
        
        // Add scripts from UserDefaults to dictionary (skip duplicates)
        for script in userDefaultsScripts {
            if scriptDict[script.title] == nil {
                scriptDict[script.title] = script
            }
        }
        
        return Array(scriptDict.values)
    }

    private func saveMergedScripts(_ scripts: [Script]) {
        // Save scripts to Firebase
        FirebaseManager.shared.saveScripts(scripts) { error in
            if let error = error {
                print("Error saving merged scripts to Firebase: \(error)")
            }
        }
        
        // Save scripts to UserDefaults
        UserDefaults.standard.saveScripts(scripts)
    }

    
    @IBAction func toggleAuthentication(_ sender: UIBarButtonItem) {
        if sessionStore.isSignedIn {
            // Show sign-out alert
            let alertController = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
            let signOutAction = UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
                self?.sessionStore.signOut()
                self?.presentSignOutAlert()
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(signOutAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true, completion: nil)
        } else {
            // Show sign-in view
            presentAuthentication()
        }
    }


    @IBAction func addNewScriptTapped(_ sender: UIButton) {
        isPremiumUser { [weak self] isPremium in
            guard let self = self else { return }

            if !isPremium && self.scripts.count >= 4 {
                self.showUpgradeAlert()
                return
            }

            let alert = UIAlertController(title: "Add New Script", message: "Choose an option", preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "Create New Script", style: .default, handler: { _ in
                self.presentEditScriptViewController(isNewScript: true)
            }))
            
            alert.addAction(UIAlertAction(title: "Import Script", style: .default, handler: { _ in
                self.importScript()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            // For iPad: Provide the location information for the popover
            if let popoverController = alert.popoverPresentationController {
                // Get the first cell
                if let firstCell = self.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) {
                    popoverController.sourceView = firstCell
                    popoverController.sourceRect = firstCell.bounds
                    popoverController.permittedArrowDirections = [.up, .down]
                } else {
                    // Fallback to the sender button if the first cell is not found
                    popoverController.sourceView = sender
                    popoverController.sourceRect = sender.bounds
                    popoverController.permittedArrowDirections = [.up, .down]
                }
            }
            
            self.present(alert, animated: true, completion: nil)
        }
    }



    func presentEditScriptViewController(isNewScript: Bool = false) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditTextView") as? EditTextView {
            editVC.delegate = self
            if isNewScript {
                editVC.script = nil // Pass nil to indicate a new script
            } else {
                editVC.script = nil // No current script in this case
            }
            present(editVC, animated: true, completion: nil)
        }
    }
    
    @IBAction func deleteAllScriptsButtonTapped(_ sender: UIButton) {
        confirmAndDeleteAllScripts()
    }
    
    func confirmAndDeleteAllScripts() {
        let alertController = UIAlertController(title: "Delete All Scripts", message: "Are you sure you want to delete all scripts? This action cannot be undone.", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteAllScripts()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }

    func deleteAllScripts() {
        if sessionStore.isSignedIn {
            FirebaseManager.shared.deleteAllScripts { [weak self] error in
                if let error = error {
                    print("Error deleting all scripts from Firebase: \(error)")
                    return
                }
                self?.clearLocalScripts()
                print("All scripts deleted from Firebase and UserDefaults")
            }
        } else {
            clearLocalScripts()
            print("All scripts deleted from UserDefaults")
        }
    }

    private func clearLocalScripts() {
        scripts.removeAll()
        UserDefaults.standard.removeObject(forKey: "ImportedScriptsCount")
        UserDefaults.standard.saveScripts(scripts) // Clear scripts in UserDefaults
        collectionView.reloadData()
        saveScripts() // Save the empty list to trigger any necessary updates
    }


    
    

    @IBAction func importScript() {
        isPremiumUser { [weak self] isPremium in
            guard let self = self else { return }
            if !isPremium && self.importedScriptsCount >= 1 {
                self.showUpgradeAlert()
                return
            }
            let supportedTypes: [UTType] = [UTType.text, UTType.pdf, UTType(filenameExtension: "docx")!]
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            self.present(documentPicker, animated: true, completion: nil)
        }
    }

 

    func displayPaywall() {
        // Implement the logic to display the paywall
        let nextVC = PaywallViewController()
        nextVC.delegate = self
        present(nextVC, animated: true, completion: nil)
    }
}

extension ScriptsCollectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scripts.count + 1 // +1 for the 'Add New Script' cell
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddNewScriptCell", for: indexPath)
            cell.layer.borderColor = UIColor.yellow.cgColor
            cell.layer.borderWidth = 2.0
            cell.layer.cornerRadius = 10.0 // Adjust the value for the desired corner radius
            cell.layer.masksToBounds = true
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ScriptCell", for: indexPath) as! ScriptCell
            let script = scripts[indexPath.item - 1] // Adjust for 'Add New Script' cell
            cell.configure(with: script)
            cell.deleteAction = { [weak self] in
                guard let self = self else { return }
                self.confirmDeleteScript(script, at: indexPath)
            }
            if isEditingMode {
                cell.startWobble()
                deleteAllBtn.isHidden = false
            } else {
                cell.stopWobble()
                deleteAllBtn.isHidden = true
            }
            cell.layer.cornerRadius = 10.0 // Adjust the value for the desired corner radius
            cell.layer.masksToBounds = true
            return cell
        }
    }

    private func confirmDeleteScript(_ script: Script, at indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Delete Script", message: "Are you sure you want to delete this script?", preferredStyle: .alert)
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteScript(script, at: indexPath)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }

    private func deleteScript(_ script: Script, at indexPath: IndexPath) {
        scripts.remove(at: indexPath.item - 1)
        saveScriptsToUserDefaults()
        
        if sessionStore.isSignedIn {
            FirebaseManager.shared.deleteScript(script) { [weak self] error in
                if let error = error {
                    print("Error deleting script from Firebase: \(error)")
                }
                self?.finalizeScriptDeletion()
            }
        } else {
            finalizeScriptDeletion()
        }
    }

    private func finalizeScriptDeletion() {
        collectionView.reloadData() // Reload the collection view to update the layout
    }




    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            addNewScriptTapped(UIButton()) // Fix: Passing a dummy UIButton() to satisfy the function signature
        } else {
            let script = scripts[indexPath.item - 1]
            print("cell selected", indexPath.item - 1)
            performSegue(withIdentifier: "showScriptDetail", sender: script)
        }
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showScriptDetail" {
            if let viewController = segue.destination as? ViewController, let script = sender as? Script {
                viewController.currentScript = script
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let movedScript = scripts.remove(at: sourceIndexPath.item - 1)
        scripts.insert(movedScript, at: destinationIndexPath.item - 1)
        saveScripts()
    }

    func collectionView(_ collectionView: UICollectionView, trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if indexPath.item == 0 {
            return nil // Prevent editing the 'Add New Script' cell
        }

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completionHandler) in
            self?.scripts.remove(at: indexPath.item - 1)
            collectionView.deleteItems(at: [indexPath])
            self?.saveScripts()
            completionHandler(true)
        }
        deleteAction.backgroundColor = .red

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
}

extension ScriptsCollectionViewController: UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let script = scripts[indexPath.item - 1]
        let itemProvider = NSItemProvider(object: script.title as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = script
        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)

        coordinator.items.forEach { item in
            if let sourceIndexPath = item.sourceIndexPath {
                collectionView.performBatchUpdates({
                    let movedScript = scripts.remove(at: sourceIndexPath.item - 1)
                    scripts.insert(movedScript, at: destinationIndexPath.item - 1)
                    collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
                }, completion: nil)
            } else {
                if let script = item.dragItem.localObject as? Script {
                    collectionView.performBatchUpdates({
                        scripts.insert(script, at: destinationIndexPath.item - 1)
                        collectionView.insertItems(at: [destinationIndexPath])
                    }, completion: nil)
                }
            }
        }
        saveScripts()
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return indexPath.item != 0 // Prevent moving the 'Add New Script' cell
    }
}

// Save scripts to UserDefaults or Firebase
extension ScriptsCollectionViewController {
    func saveScripts() {
        if sessionStore.isSignedIn {
            FirebaseManager.shared.saveScripts(scripts) { error in
                if let error = error {
                    print("Error saving scripts: \(error)")
                } else {
                    print("Scripts saved to Firebase successfully")
                }
            }
        }
        saveScriptsToUserDefaults()
    }
    
    private func saveScriptsToUserDefaults() {
        UserDefaults.standard.saveScripts(scripts)
    }
}



extension ScriptsCollectionViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }
        // Validate file type
        let fileType = selectedFileURL.pathExtension.lowercased()
        if fileType != "txt" && fileType != "docx" && fileType != "pdf" {
            showAlert(title: "Unsupported File Type", message: "Please select a .txt, .docx, or .pdf file.")
            return
        }

        // Show confirmation alert
        let alert = UIAlertController(title: "Confirm Import",
                                      message: "Do wish to import this script?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.handleFileImport(url: selectedFileURL)
        })
        present(alert, animated: true, completion: nil)
    }

    func handleFileImport(url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                showAlert(title: "Access Error", message: "Couldn't access the file.")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let fileData = try Data(contentsOf: url)
            if let fileText = extractText(from: fileData, fileType: url.pathExtension) {
                let content = fileText
                let newScript = Script(
                    title: url.deletingPathExtension().lastPathComponent, // Removing file extension from title
                    content: content,
                    lastModified: Date() // Current date and time
                )
                presentEditScriptViewController(with: newScript)
            } else {
                showAlert(title: "Extraction Error", message: "Failed to extract text from the file.")
            }
        } catch {
            showAlert(title: "Read Error", message: "Failed to read the file: \(error.localizedDescription)")
        }
    }


    func extractText(from data: Data, fileType: String) -> String? {
        switch fileType.lowercased() {
        case "docx":
            return extractTextFromDOCX(data: data)
        case "pdf":
            return extractTextFromPDF(data: data)
        case "txt":
            return extractTextFromTXT(data: data)
        default:
            return nil
        }
    }

    func extractTextFromPDF(data: Data) -> String? {
        guard let pdfDocument = PDFDocument(data: data) else {
            print("Failed to create PDF document")
            return nil
        }

        var text = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            text += page.string ?? ""
            text += "\n"
        }
        return text
    }

    func extractTextFromTXT(data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }

    func extractTextFromDOCX(data: Data) -> String? {
        struct Document: Codable {
            let body: Body

            enum CodingKeys: String, CodingKey {
                case body = "w:body"
            }
        }

        struct Body: Codable {
            let paragraphs: [Paragraph]

            enum CodingKeys: String, CodingKey {
                case paragraphs = "w:p"
            }
        }

        struct Paragraph: Codable {
            let runs: [Run]

            enum CodingKeys: String, CodingKey {
                case runs = "w:r"
            }
        }

        struct Run: Codable {
            let text: Text?

            enum CodingKeys: String, CodingKey {
                case text = "w:t"
            }
        }

        struct Text: Codable {
            let value: String

            enum CodingKeys: String, CodingKey {
                case value = ""
            }
        }

        do {
            let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)
            
            let archive = try Archive(data: data, accessMode: .read)
            for entry in archive {
                let destinationURL = tempDirURL.appendingPathComponent(entry.path)
                try archive.extract(entry, to: destinationURL)
            }

            let documentXMLPath = tempDirURL.appendingPathComponent("word/document.xml")
            let documentXMLData = try Data(contentsOf: documentXMLPath)
            let decoder = XMLDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys

            let document = try decoder.decode(Document.self, from: documentXMLData)

            var text = ""
            for paragraph in document.body.paragraphs {
                var paragraphText = ""
                for run in paragraph.runs {
                    if let runText = run.text?.value {
                        paragraphText += runText
                    }
                }
                text += paragraphText + "\n"
            }

            try FileManager.default.removeItem(at: tempDirURL)

            return text
        } catch {
            print("Failed to parse .docx file: \(error)")
            return nil
        }
    }

    func presentEditScriptViewController(with script: Script) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditTextView") as? EditTextView {
            editVC.delegate = self
            editVC.script = script
            present(editVC, animated: true, completion: nil)
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        if let viewController = getTopViewController() {
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    func getTopViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let rootViewController = windowScene.windows.first?.rootViewController {
                var topController: UIViewController = rootViewController
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                return topController
            }
        }
        return nil
    }
}

extension ScriptsCollectionViewController: EditScriptDelegate {
    func updateScript(_ script: Script) {
        if let index = scripts.firstIndex(where: { $0.title == script.title }) {
            scripts[index] = script
        } else {
            scripts.append(script)
        }
        
        // Sort scripts by date
        sortScriptsByDate()
        
        collectionView.reloadData()
    }
}

extension ScriptsCollectionViewController: GADBannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("Banner ad loaded successfully.")
    }

    func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
        print("Failed to load banner ad: \(error.localizedDescription)")
    }
}

