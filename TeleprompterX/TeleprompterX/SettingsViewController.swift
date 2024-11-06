import UIKit
import FirebaseAuth
import MessageUI
import StoreKit
import RevenueCat
import RevenueCatUI
import SwiftUI
import AVFoundation

// Add an enum for the background audio options
enum BackgroundAudioOption: String, CaseIterable {
    case none = "None"
    case metronome = "Metronome"
}

protocol SettingsDelegate: AnyObject {
    func didToggleWatermark(isEnabled: Bool)
    func didTogglePagination(_ isEnabled: Bool)
    func presentMarginSettings()
    func didUpdateMargins(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)
    func didSelectBackgroundColor(_ color: UIColor)
    func didSelectFontColor(_ color: UIColor)
    func didChangeFontSize(_ fontSize: CGFloat)
    func didChangeLineHeight(_ lineHeight: CGFloat)
    func didSelectFont(_ selectedFont: UIFont)
    func didSelectTextAlignment(_ textAlignment: NSTextAlignment)
    func didToggleEyeFocusMode(_ isEnabled: Bool)
    func didToggleTimedSpeechMode(_ isEnabled: Bool)
    func didChangeTimedSpeechMode(isEnabled: Bool)
    func didChangeTimedSpeechTime(_ timeInterval: TimeInterval)
    func didToggleCueMode(isEnabled: Bool)
    func didToggleReverseMode(_isEnabled: Bool)
    func didToggleStartTimerMode(_ isEnabled: Bool)
    func didChangeStartTimerTime(_ timeInterval: TimeInterval)
    func didToggleTapToScroll(_ isEnabled: Bool)
    func didToggleExternalDisplay(isEnabled: Bool)
    func didChangeHighlightLineNumber(_ lineNumber: Int)
     func didChangeHighlightLineColor(_ color: UIColor)
     func didToggleHighlightLine(_ isEnabled: Bool)
}

class SettingsViewController: UIViewController, TimedSpeechCellDelegate  {
  
    var isExternalDisplayEnabled: Bool = false
    var isTapToScrollEnabled: Bool {
           get { UserDefaults.standard.bool(forKey: "TapToScrollEnabled") }
           set { UserDefaults.standard.set(newValue, forKey: "TapToScrollEnabled") }
       }
    
   
    
    var hasTheUserUpgraded: Bool = false
    
    func didToggleTimedSpeechRestriction(_ isEnabled: Bool) {
        
    }
    
    var paginationEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "PaginationEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "PaginationEnabled") }
    }

    var videoCaptionsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "VideoCaptionsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "VideoCaptionsEnabled") }
    }
    private var sessionStore = SessionStore()

    var selectedBackgroundAudio: BackgroundAudioOption {
        get {
            if let savedOption = UserDefaults.standard.string(forKey: "BackgroundAudioOption"),
               let option = BackgroundAudioOption(rawValue: savedOption) {
                return option
            }
            return .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "BackgroundAudioOption")
        }
    }

    @IBOutlet weak var tableView: UITableView!

    var settingsOptions = [
        "Background Colour", "Font Colour", "Font Size", "Line Height", "Font Face", "Alignment", "Eye-focus mode",
        "Talk Timer", "Cue Mode", "Reverse Mode", "Countdown", "Tap to Scroll", "Pagination", "Background Audio for PiP",
        "Video Captions", "Highlight Line", "Margins", "Game Controller", "Rate the App", "Upgrade to Pro", "Contact Support", "Suggest a Feature",
        "Sign In", "Delete Account", "Terms and Conditions", "Privacy Policy", "External Display","Watermark"
    ]



    
    weak var delegate: SettingsDelegate?

    // Variable to store the selected index path
    var selectedIndexPath: IndexPath?
    var currentFontSize: CGFloat = 17 // Default value
    var currentLineHeight: CGFloat? // Default value for line height

    var reverseModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "ReverseModeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "ReverseModeEnabled") }
    }

    var startTimerModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "StartTimerModeEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "StartTimerModeEnabled") }
    }

    var startTimerTime: TimeInterval {
        get { UserDefaults.standard.double(forKey: "StartTimerTime") }
        set { UserDefaults.standard.set(newValue, forKey: "StartTimerTime") }
    }

    var eyeFocusEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "EyeFocusEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "EyeFocusEnabled") }
    }

    var cueEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "cueEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "cueEnabled") }
    }

    var timedSpeechEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "TimedSpeechEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "TimedSpeechEnabled") }
    }

    var timedSpeechTime: TimeInterval {
        get { UserDefaults.standard.double(forKey: "TimedSpeechTime") }
        set { UserDefaults.standard.set(newValue, forKey: "TimedSpeechTime") }
    }

    var isTimedSpeechEnabled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light
        setupTableHeaderView()
        tableView.register(ExternalDisplayCell.self, forCellReuseIdentifier: "ExternalDisplayCell")
        tableView.register(TimedSpeechCell.self, forCellReuseIdentifier: "TimedSpeechCell")
        tableView.register(TimerSettingsCell.self, forCellReuseIdentifier: "TimerSettingsCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell_VideoCaptions")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell_ExternalDisplay") // Register the new cell
        registerCells()
        tableView.dataSource = self
        tableView.delegate = self

        if let savedLineHeight = UserDefaults.standard.value(forKey: "LineHeight") as? CGFloat {
            currentLineHeight = savedLineHeight
        } else {
            currentLineHeight = 51.0 // Set your default value here
        }
        checkPremiumStatus()
        print("Line height on load =", currentLineHeight!)
        NotificationCenter.default.addObserver(self, selector: #selector(authStateDidChange), name: .authStateDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .authStateDidChange, object: nil)
    }

    @objc func authStateDidChange() {
        tableView.reloadData()
    }

    func presentAuthentication() {
        if !sessionStore.isSignedIn {
            let authView = UIHostingController(rootView: AuthenticationView(completion: { [weak self] message in
                self?.dismiss(animated: true, completion: {
                    if let message = message {
                        self?.presentAlert(title: "Authentication", message: message)
                    }
                })
            }).environmentObject(sessionStore))
            authView.modalPresentationStyle = .pageSheet
            if let sheet = authView.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            present(authView, animated: true, completion: nil)
        }
    }

    func presentAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.tableView.reloadData()
        }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }

    func presentSignOutAlert() {
        let alertController = UIAlertController(title: "Signed Out", message: "You have been signed out.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.tableView.reloadData()
        }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }

    func didToggleTimedSpeechMode(_ isEnabled: Bool) { }

    func didChangeTimedSpeechTime(_ timeInSeconds: TimeInterval) { }

    func setupTableHeaderView() {
        // Ensure tableView is not nil before using it
        guard let tableView = tableView else { return }

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 60))
        headerView.backgroundColor = .white

        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .black
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        tableView.tableHeaderView = headerView
    }

    func registerCells() {
        let cellIdentifiers = (0...24).map { "SettingsCell_\($0)" }
        for identifier in cellIdentifiers {
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: identifier)
        }
    }

    @objc func lineHeightStepperValueChanged(_ stepper: UIStepper) {
        let lineHeight = CGFloat(stepper.value)
        currentLineHeight = lineHeight
        print("Line height stepper value changed to: \(lineHeight)")
        delegate?.didChangeLineHeight(lineHeight)
    }

    @objc func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func settingsButtonTapped() {
        let generalSettingsVC = GeneralSettingsViewController() // Instantiate GeneralSettingsViewController
        let navController = UINavigationController(rootViewController: generalSettingsVC) // Embed in a navigation controller
        navController.modalPresentationStyle = .formSheet // Set modal presentation style to form sheet
        present(navController, animated: true, completion: nil) // Present modally
    }

    @objc func timerSwitchToggled(_ timerSwitch: UISwitch) {
        startTimerModeEnabled = timerSwitch.isOn
        UserDefaults.standard.set(startTimerModeEnabled, forKey: "StartTimerModeEnabled")
        print("Timer mode toggled: \(startTimerModeEnabled)")
        tableView.reloadData()
        delegate?.didToggleStartTimerMode(startTimerModeEnabled)
    }

    @objc func timerStepperValueChanged(_ stepper: UIStepper) {
        timedSpeechTime = stepper.value
        UserDefaults.standard.set(timedSpeechTime, forKey: "TimedSpeechTime")
        tableView.reloadData()
        delegate?.didChangeStartTimerTime(timedSpeechTime)
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 8 // Updated to 8 sections
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1 // Upgrade section
        case 1: return 4 // Formatting section
        case 2: return 3 // Spacing section (updated to include Margins)
        case 3: return 10 // Controls section (updated to include Tap to Scroll and Pagination)
        case 4: return 2 // Displays section
        case 5: return 1 // Wireless Command section
        case 6: return 4 // From the Developers section
        case 7: return 4 // Account section
        default: return 0
        }
    }



    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return configureUpgradeOfferCell(for: indexPath)
        }

        var reuseIdentifier: String = ""
        var row: Int = 0

        switch indexPath.section {
            case 1:
                if indexPath.row <= 2 {
                    row = indexPath.row
                } else if indexPath.row == 3 {
                    row = 4
                }
            case 2:
            if indexPath.row == 0 {
                        row = 3
                    } else if indexPath.row == 1 {
                        row = 5
                    } else if indexPath.row == 2 {
                        return configureMarginsCell(for: indexPath)
                    }
            case 3:
                if indexPath.row <= 5 {
                    row = indexPath.row + 6
                } else if indexPath.row == 6 {
                    return configureTapToScrollCell(for: indexPath)
                } else if indexPath.row == 7 {
                    return configurePaginationCell(for: indexPath)
                } else if indexPath.row == 8 {
                    return configureVideoCaptionsCell(for: indexPath)
                } else if indexPath.row == 9 {
                    return configureHighlightLineCell(for: indexPath) // Add this line
                }
            case 4:
                if indexPath.row == 0 {
                    return configureExternalDisplayCell(for: indexPath)
                } else if indexPath.row == 1 {
                    return configureWatermarkCell(for: indexPath)
                }
            case 5:
                row = indexPath.row + 13
            case 6:
                row = indexPath.row + 17
            case 7:
                row = indexPath.row + 21
            default:
                fatalError("Unexpected section \(indexPath.section)")
        }

        if row == 7 {
            reuseIdentifier = "TimedSpeechCell"
        } else if row == 10 {
            reuseIdentifier = "TimerSettingsCell"
        } else {
            reuseIdentifier = "SettingsCell_\(row)"
        }

        var cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.textLabel?.text = settingsOptions[row]

        if indexPath.section == 3 && indexPath.row == 5 {
            cell = configureBackgroundAudioCell(cell)
        } else {
            cell = configureSettingCell(cell, for: row)
        }

        return cell
    }


    func configureHighlightLineCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SettingsCell_HighlightLine")
        
        // Create a label for the title
        let titleLabel = UILabel()
        titleLabel.text = "Highlight Line"
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(titleLabel)
        
        // Create a stepper
        let stepper = UIStepper()
        stepper.minimumValue = 1
        stepper.maximumValue = 10
        stepper.value = Double(UserDefaults.standard.highlightLineNumber)
        stepper.addTarget(self, action: #selector(highlightLineStepperChanged(_:)), for: .valueChanged)
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.tag = 1 // Add a tag to identify the stepper
        cell.contentView.addSubview(stepper)
        
        // Create a label to display the stepper value
        let valueLabel = UILabel()
        valueLabel.text = "\(UserDefaults.standard.highlightLineNumber)"
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.tag = 2 // Add a tag to identify the label
        cell.contentView.addSubview(valueLabel)
        
        // Create a view for the color square
        let colorView = UIView()
        colorView.backgroundColor = UserDefaults.standard.highlightLineColor
        colorView.layer.borderWidth = 1.0
        colorView.layer.borderColor = UIColor.black.cgColor
        colorView.translatesAutoresizingMaskIntoConstraints = false
        colorView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(highlightLineColorTapped(_:)))
        colorView.addGestureRecognizer(tapGesture)
        colorView.tag = 3 // Add a tag to identify the color view
        cell.contentView.addSubview(colorView)
        
        // Create a switch to toggle the highlight line feature
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = UserDefaults.standard.highlightLineEnabled
        toggleSwitch.addTarget(self, action: #selector(highlightLineSwitchToggled(_:)), for: .valueChanged)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(toggleSwitch)
        
        // Enable/disable the stepper and color view based on the switch state
        stepper.isEnabled = toggleSwitch.isOn
        colorView.alpha = toggleSwitch.isOn ? 1.0 : 0.3
        
        // Add constraints
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 15),
            titleLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            stepper.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            stepper.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            valueLabel.leadingAnchor.constraint(equalTo: stepper.trailingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            colorView.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 10),
            colorView.widthAnchor.constraint(equalToConstant: 30),
            colorView.heightAnchor.constraint(equalToConstant: 30),
            colorView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            toggleSwitch.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 10),
            toggleSwitch.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -15),
            toggleSwitch.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        
        return cell
    }



    @objc func highlightLineStepperChanged(_ stepper: UIStepper) {
        let lineNumber = Int(stepper.value)
        UserDefaults.standard.highlightLineNumber = lineNumber
        if let cell = tableView.cellForRow(at: IndexPath(row: 9, section: 3)) {
            if let valueLabel = cell.contentView.viewWithTag(2) as? UILabel {
                valueLabel.text = "\(lineNumber)"
            }
        }
        delegate?.didChangeHighlightLineNumber(lineNumber)
    }

    @objc func highlightLineColorTapped(_ sender: UITapGestureRecognizer) {
        if UserDefaults.standard.highlightLineEnabled {
            selectedIndexPath = IndexPath(row: 9, section: 3) // Set the selectedIndexPath
            let colorPicker = UIColorPickerViewController()
            colorPicker.delegate = self
            colorPicker.view.tag = 3 // Add a tag to identify the color picker
            present(colorPicker, animated: true, completion: nil)
        }
    }

    @objc func highlightLineSwitchToggled(_ toggleSwitch: UISwitch) {
        let isEnabled = toggleSwitch.isOn
        UserDefaults.standard.highlightLineEnabled = isEnabled
        if let cell = tableView.cellForRow(at: IndexPath(row: 9, section: 3)) {
            if let stepper = cell.contentView.viewWithTag(1) as? UIStepper {
                stepper.isEnabled = isEnabled
            }
            if let colorView = cell.contentView.viewWithTag(3) {
                colorView.alpha = isEnabled ? 1.0 : 0.3
                colorView.isUserInteractionEnabled = isEnabled // Enable/disable user interaction
            }
        }
        delegate?.didToggleHighlightLine(isEnabled)
    }
    func configureMarginsCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SettingsCell_Margins")
        cell.textLabel?.text = "Margins"
        return cell
    }



    func configurePaginationCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SettingsCell_Pagination")
        cell.textLabel?.text = "Pagination"
        
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = paginationEnabled
        toggleSwitch.addTarget(self, action: #selector(paginationToggled(_:)), for: .valueChanged)
        
        cell.accessoryView = toggleSwitch
        return cell
    }

    func configureWatermarkCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SettingsCell_Watermark")
        cell.textLabel?.text = "Watermark"
        
        let toggleSwitch = UISwitch()
        let isWatermarkEnabled = UserDefaults.standard.bool(forKey: "WatermarkEnabled")
        
        if hasTheUserUpgraded {
            toggleSwitch.isOn = isWatermarkEnabled
        } else {
            toggleSwitch.isOn = true
            UserDefaults.standard.set(true, forKey: "WatermarkEnabled")
        }
        
        toggleSwitch.addTarget(self, action: #selector(watermarkToggled(_:)), for: .valueChanged)
        
        cell.accessoryView = toggleSwitch
        return cell
    }

    @objc func watermarkToggled(_ toggleSwitch: UISwitch) {
        if hasTheUserUpgraded {
            UserDefaults.standard.set(toggleSwitch.isOn, forKey: "WatermarkEnabled")
            delegate?.didToggleWatermark(isEnabled: toggleSwitch.isOn)
        } else {
            if toggleSwitch.isOn {
                UserDefaults.standard.set(true, forKey: "WatermarkEnabled")
            } else {
                toggleSwitch.setOn(true, animated: true)
                presentPremiumUpgradeAlertForWatermark()
            }
        }
    }

    func presentPremiumUpgradeAlertForWatermark() {
        let alertController = UIAlertController(
            title: "Premium Feature",
            message: "Turning off watermarks is available only for premium users. Would you like to upgrade?",
            preferredStyle: .alert
        )
        
        let upgradeAction = UIAlertAction(title: "Upgrade", style: .default) { [weak self] _ in
            self?.presentPaywall()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(upgradeAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }



    func configureUpgradeOfferCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "UpgradeOfferCell")
       
            cell.textLabel?.text = "Recommend Teleprompter X to a Friend"
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            cell.textLabel?.adjustsFontSizeToFitWidth = true // Allow text to shrink to fit the label
            cell.textLabel?.minimumScaleFactor = 0.5 // Set a minimum scale factor for shrinking
            
            cell.detailTextLabel?.text = "Share the love!"
            cell.detailTextLabel?.textColor = .blue
        
        return cell
    }
    
    func configureTapToScrollCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "SettingsCell_TapToScroll")
        cell.textLabel?.text = "Tap to Scroll"
        
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = isTapToScrollEnabled
        toggleSwitch.addTarget(self, action: #selector(tapToScrollToggled(_:)), for: .valueChanged)
        
        cell.accessoryView = toggleSwitch
        return cell
    }

    @objc func tapToScrollToggled(_ toggleSwitch: UISwitch) {
        isTapToScrollEnabled = toggleSwitch.isOn
        UserDefaults.standard.set(isTapToScrollEnabled, forKey: "TapToScrollEnabled")
        delegate?.didToggleTapToScroll(isTapToScrollEnabled)
    }



    func configureVideoCaptionsCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell_VideoCaptions", for: indexPath)
        cell.textLabel?.text = "Video Captions"
        
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = videoCaptionsEnabled
        toggleSwitch.addTarget(self, action: #selector(videoCaptionsToggled(_:)), for: .valueChanged)
        
        cell.accessoryView = toggleSwitch
        cell.isUserInteractionEnabled = true
        
        // Check premium status and update UI accordingly
        checkthePremiumStatus { isPremium in
            DispatchQueue.main.async {
                cell.textLabel?.textColor = .black // Ensure text color is always black
            }
        }
        
        return cell
    }


    @objc func videoCaptionsToggled(_ toggleSwitch: UISwitch) {
        checkthePremiumStatus { [weak self] isPremium in
            DispatchQueue.main.async {
                if isPremium {
                    self?.hasTheUserUpgraded = true
                    self?.videoCaptionsEnabled = toggleSwitch.isOn
                    UserDefaults.standard.set(toggleSwitch.isOn, forKey: "VideoCaptionsEnabled")
                } else {
                    if toggleSwitch.isOn {
                        self?.hasTheUserUpgraded = false
                        toggleSwitch.setOn(false, animated: true)
                        self?.presentPremiumUpgradeAlert()
                        print("Not premium! should be calling upgrade")
                    }
                }
            }
        }
    }



    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkthePremiumStatus { isPremium in
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
    }
    

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }


    @objc func paginationToggled(_ toggleSwitch: UISwitch) {
        paginationEnabled = toggleSwitch.isOn
        UserDefaults.standard.set(paginationEnabled, forKey: "PaginationEnabled")
        delegate?.didTogglePagination(paginationEnabled)
    }


    
    func presentPremiumUpgradeAlert() {
        let alertController = UIAlertController(
            title: "Premium Feature",
            message: "Video captions are available only for premium users. Would you like to upgrade?",
            preferredStyle: .alert
        )
        
        let upgradeAction = UIAlertAction(title: "Upgrade", style: .default) { [weak self] _ in
            self?.presentPaywall()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(upgradeAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }

    
    func presentPaywall() {
        let nextVC = PaywallViewController()
        nextVC.delegate = self
        present(nextVC, animated: true, completion: nil)
    }
    
    func checkthePremiumStatus(completion: @escaping (Bool) -> Void) {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if let error = error {
                print("Error fetching customer info: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if customerInfo?.entitlements["Pro Upgrade"]?.isActive == true {
                print("Customer has upgraded")
                completion(true)
            } else {
                print("Customer has NOT upgraded")
                completion(false)
            }
        }
    }




    
    func configureBackgroundAudioCell(_ cell: UITableViewCell) -> UITableViewCell {
        cell.textLabel?.text = "Background Audio for PiP"
        cell.detailTextLabel?.text = selectedBackgroundAudio.rawValue
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func configureSettingCell(_ cell: UITableViewCell, for row: Int) -> UITableViewCell {
        switch row {
        case 0:
            configureBackgroundColorCell(cell)
        case 1:
            configureFontColorCell(cell)
        case 2:
            configureFontSizeCell(cell)
        case 3:
            configureLineHeightCell(cell)
        case 4:
            configureFontFaceCell(cell)
        case 5:
            configureTextAlignmentCell(cell)
        case 6:
            configureEyeFocusModeCell(cell)
        case 7:
            guard let timedSpeechCell = cell as? TimedSpeechCell else { return UITableViewCell() }
            timedSpeechCell.delegate = self
        case 8:
            configureCueModeCell(cell)
        case 9:
            configureReverseModeCell(cell)
        case 10:
            guard let timerSettingsCell = cell as? TimerSettingsCell else { return UITableViewCell() }
            configureTimerSettingsCell(timerSettingsCell)
        case 16:
            configureSignInCell(cell)
        default:
            break
        }
        return cell
    }

    func configureBackgroundColorCell(_ cell: UITableViewCell) {
        let backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        backgroundView.backgroundColor = UserDefaults.standard.color(forKey: "BackgroundColor") ?? .black
        backgroundView.layer.borderWidth = 1.0
        backgroundView.layer.borderColor = UIColor.black.cgColor
        backgroundView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundColorTapped(_:)))
        backgroundView.addGestureRecognizer(tapGesture)
        cell.accessoryView = backgroundView
        configureCellInteractivity(cell, isEnabled: !isTimedSpeechEnabled)
    }

    func configureFontColorCell(_ cell: UITableViewCell) {
        let fontView = UIView(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        fontView.backgroundColor = UserDefaults.standard.color(forKey: "FontColor") ?? .white
        fontView.layer.borderWidth = 1.0
        fontView.layer.borderColor = UIColor.black.cgColor
        fontView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(fontColorTapped(_:)))
        fontView.addGestureRecognizer(tapGesture)
        cell.accessoryView = fontView
        configureCellInteractivity(cell, isEnabled: !isTimedSpeechEnabled)
    }


    func configureFontSizeCell(_ cell: UITableViewCell) {
        // Remove any existing font size label to prevent duplication
        cell.contentView.viewWithTag(100)?.removeFromSuperview()
        
        let fontSizeLabel = UILabel(frame: CGRect(x: 20, y: 0, width: 50, height: 30)) // Adjust the x position
        fontSizeLabel.text = "\(Int(currentFontSize))"
        fontSizeLabel.tag = 100 // Set a unique tag
        fontSizeLabel.textAlignment = .left // Change to left alignment
        cell.contentView.addSubview(fontSizeLabel) // Add as subview

        let stepper = UIStepper()
        stepper.minimumValue = 10
        stepper.maximumValue = 100
        stepper.value = Double(currentFontSize) // Set initial value to current font size
        stepper.addTarget(self, action: #selector(fontSizeStepperValueChanged(_:)), for: .valueChanged)
        cell.contentView.addSubview(stepper) // Add as subview

        // Position the stepper to the right of the cell's content view
        stepper.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stepper.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            stepper.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20)
        ])

        // Position the font label to the left of the stepper with a distance equal to the width of the font size label
        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fontSizeLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            fontSizeLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -8) // Adjust the constant if needed
        ])

        // Adjust the font size label's frame to be vertically centered
        fontSizeLabel.sizeToFit()

        configureCellInteractivity(cell, isEnabled: !isTimedSpeechEnabled)
    }


    func configureLineHeightCell(_ cell: UITableViewCell) {
        let stepper = UIStepper()
        stepper.minimumValue = 0.5
        stepper.maximumValue = 100.0
        stepper.stepValue = 5
        stepper.value = Double(currentLineHeight ?? -11.0) // Set initial value to current line height
        stepper.addTarget(self, action: #selector(lineHeightStepperValueChanged(_:)), for: .valueChanged)
        cell.accessoryView = stepper

        configureCellInteractivity(cell, isEnabled: !isTimedSpeechEnabled)
    }

    func configureFontFaceCell(_ cell: UITableViewCell) {
        let fontLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 30))
        fontLabel.textAlignment = .right

        if let fontData = UserDefaults.standard.data(forKey: "SelectedFont"),
           let selectedFont = NSKeyedUnarchiver.unarchiveObject(with: fontData) as? UIFont {
            fontLabel.text = selectedFont.fontName
            fontLabel.font = selectedFont.withSize(UIFont.systemFontSize)
        }

        cell.accessoryView = fontLabel
        // Adjust the font label's frame to be vertically centered
        fontLabel.sizeToFit()
        fontLabel.frame.origin.y = (cell.contentView.bounds.height - fontLabel.frame.height) / 2.0

        configureCellInteractivity(cell, isEnabled: !isTimedSpeechEnabled)
    }

    func configureTextAlignmentCell(_ cell: UITableViewCell) {
        let alignmentSegmentedControl = UISegmentedControl(items: ["Left", "Center", "Right"])
        alignmentSegmentedControl.selectedSegmentIndex = UserDefaults.standard.integer(forKey: "TextAlignment")
        alignmentSegmentedControl.addTarget(self, action: #selector(alignmentSegmentedControlValueChanged(_:)), for: .valueChanged)
        cell.accessoryView = alignmentSegmentedControl

        configureCellInteractivity(cell, isEnabled: !isTimedSpeechEnabled)
    }

    func configureEyeFocusModeCell(_ cell: UITableViewCell) {
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = eyeFocusEnabled
        toggleSwitch.addTarget(self, action: #selector(eyeFocusModeToggled(_:)), for: .valueChanged)
        cell.accessoryView = toggleSwitch
        cell.textLabel?.textColor = .black
    }

    func configureCueModeCell(_ cell: UITableViewCell) {
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = cueEnabled
        toggleSwitch.addTarget(self, action: #selector(cueModeToggled(_:)), for: .valueChanged)
        cell.accessoryView = toggleSwitch
        cell.textLabel?.textColor = .black
    }

    func configureReverseModeCell(_ cell: UITableViewCell) {
        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = reverseModeEnabled
        toggleSwitch.addTarget(self, action: #selector(reverseModeToggled(_:)), for: .valueChanged)
        cell.accessoryView = toggleSwitch
    }

    func configureTimerSettingsCell(_ cell: TimerSettingsCell) {
        cell.timerSwitch.isOn = startTimerModeEnabled
        cell.stepper.value = startTimerTime
        cell.timeLabel.text = formattedTime(startTimerTime)

        // Enable or disable the stepper based on the switch state
        cell.stepper.isEnabled = startTimerModeEnabled

        cell.textLabel?.textColor = .black
        cell.textLabel?.text = settingsOptions[10]
    }


    func configureSignInCell(_ cell: UITableViewCell) {
        cell.textLabel?.text = sessionStore.isSignedIn ? "Sign Out" : "Sign In"
    }

    func configureCellInteractivity(_ cell: UITableViewCell, isEnabled: Bool) {
        cell.isUserInteractionEnabled = isEnabled
        cell.textLabel?.textColor = isEnabled ? .black : .gray
        cell.accessoryView?.alpha = isEnabled ? 1.0 : 0.3
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // Save the selected index path
        selectedIndexPath = indexPath

        if indexPath.section == 0 {
            
          
                //Show the email
                sendRecommendationEmail()
           
        }

        if indexPath.section == 3 && indexPath.row == 5 {
            presentBackgroundAudioOptions()
        }
        
        if indexPath.section == 3 && indexPath.row == 6 {
            // Handle the row at Controls section
        }

        switch indexPath.section {
        case 1:
            handleSection1Selection(indexPath.row)
        case 2:
            handleSection2Selection(indexPath.row)
        case 3:
            handleSection3Selection(indexPath.row)
        case 4:
            handleSection4Selection(indexPath.row) // Displays
        case 5:
            handleSection5Selection(indexPath.row)
        case 6:
            handleSection6Selection(indexPath.row)
        case 7:
            handleSection7Selection(indexPath.row)
        default:
            break
        }
    }

    
    

    func configureExternalDisplayCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ExternalDisplayCell", for: indexPath) as? ExternalDisplayCell else {
            return UITableViewCell()
        }
        cell.titleLabel.text = "External Display"
        let isEnabled = UserDefaults.standard.bool(forKey: "ExternalDisplayEnabled")
        cell.toggleSwitch.isOn = isEnabled
        cell.toggleSwitch.addTarget(self, action: #selector(externalDisplayToggled(_:)), for: .valueChanged)
        return cell
    }

    @objc func externalDisplayToggled(_ toggleSwitch: UISwitch) {
        isExternalDisplayEnabled = toggleSwitch.isOn
        UserDefaults.standard.set(isExternalDisplayEnabled, forKey: "ExternalDisplayEnabled")
        delegate?.didToggleExternalDisplay(isEnabled: isExternalDisplayEnabled)
    }
    
    
    //RECOMMENDATION EMAIL
    func sendRecommendationEmail() {
        // Text to share
        let textToShare = "I've been using this amazing Teleprompter App and it's free to download! You can get it from https://apps.apple.com/sk/app/teleprompter-x/id6502788841"
        
        // Load the image you want to share
        guard let imageToShare = UIImage(named: "AppIcon") else {
            print("Error: Image not found")
            return
        }
        
        // Items to share
        let items: [Any] = [textToShare, imageToShare]
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Exclude some activity types from the list (optional)
        activityVC.excludedActivityTypes = [.postToFacebook, .postToTwitter, .postToWeibo, .message, .print, .assignToContact, .saveToCameraRoll, .addToReadingList, .postToFlickr, .postToVimeo, .postToTencentWeibo]
        
        // For iPads, we need to specify the sourceView
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        self.present(activityVC, animated: true, completion: nil)
    }


    @objc func backgroundColorTapped(_ sender: UITapGestureRecognizer) {
        selectedIndexPath = IndexPath(row: 0, section: 1) // Assuming Background Color is at row 0, section 1
        let colorPicker = UIColorPickerViewController()
        colorPicker.delegate = self
        present(colorPicker, animated: true, completion: nil)
    }

    @objc func fontColorTapped(_ sender: UITapGestureRecognizer) {
        selectedIndexPath = IndexPath(row: 1, section: 1) // Assuming Font Color is at row 1, section 1
        let colorPicker = UIColorPickerViewController()
        colorPicker.delegate = self
        present(colorPicker, animated: true, completion: nil)
    }

  

    
    //FORMATTING
    func handleSection1Selection(_ row: Int) {
        switch row {
        case 0, 1:
            let colorPicker = UIColorPickerViewController()
            colorPicker.delegate = self
            present(colorPicker, animated: true, completion: nil)
        case 2:
            // Implement logic to present a view for adjusting font size
            break
        case 3:
            presentFontPicker()
        default:
            break
        }
    }

   
    //SPACING
    func handleSection2Selection(_ row: Int) {
        print("handleSection2Selection called with row: \(row)")
        if row == 2 {
            print("Margins selected")
            presentMarginSettings()
        }
    }

    private func presentMarginSettings() {
        print("presentMarginSettings called")
        let marginSettingsVC = MarginSettingsViewController()
        marginSettingsVC.topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin")) // Load initial margin values
        marginSettingsVC.bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
        marginSettingsVC.leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
        marginSettingsVC.rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))
        marginSettingsVC.modalPresentationStyle = .overCurrentContext
        marginSettingsVC.modalTransitionStyle = .crossDissolve
        marginSettingsVC.visibilityDelegate = self // Set the visibility delegate

        marginSettingsVC.onSave = { [weak self] top, bottom, left, right in
            guard let self = self else { return }
            // Assuming you have a reference to the presenting view controller
            if let viewController = self.presentingViewController as? ViewController {
                viewController.saveMarginsToDefaults(top: top, bottom: bottom, left: left, right: right)
                // Ensure textView updates immediately
                viewController.textView.textContainerInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            }
        }

        present(marginSettingsVC, animated: true, completion: nil)
    }



    //CONTROLS
//    func handleSection3Selection(_ row: Int) {
//        switch row {
//        case 0:
//            print("Eye Focus")
//        case 1:
//            print("Talk Timer")
//        case 2:
//            print("Cue Mode")
//        case 3:
//            print("Reverse Mode")
//        case 4:
//            print("Countdown")
//        case 5:
//            print("Background Audio")
//        case 6:
//            print("Tap to Scroll")
//            // Add logic to handle the selection of Tap to Scroll
//        case 7:
//            print("Pagination")
//            // Add logic to handle the selection of "Pagination"
//        case 8:
//            print("Video Captions")
//           
//        default:
//            break
//        }
//    }
    
    
    
    //CONTROLS
    func handleSection3Selection(_ row: Int) {
        switch row {
        case 0:
            print("Eye Focus")
        case 1:
            print("Talk Timer")
        case 2:
            print("Cue Mode")
        case 3:
            print("Reverse Mode")
        case 4:
            print("Countdown")
        case 5:
            print("Background Audio")
            presentBackgroundAudioOptions()
        case 6:
            print("Tap to Scroll")
            // Add logic to handle the selection of Tap to Scroll
            presentComingSoonAlert()
        case 7:
            print("Pagination")
            // Add logic to handle the selection of "Pagination"
            presentComingSoonAlert()

        case 8:
            print("Video Captions")
           
        default:
            break
        }
    }

    // Function to present the "Coming Soon" alert
    func presentComingSoonAlert() {
        let alertController = UIAlertController(title: "Coming Soon", message: "This feature is coming soon.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    
    
    
    

    //DISPLAY
    func handleSection4Selection(_ row: Int) {
        // Handle the row for Displays section
        if row == 0 {
            print("External Display selected")
            // Add logic to handle the selection of "External Display"
            
            presentComingSoonAlert()

        }
    }

    //WIRELESS COMMAND
    func handleSection5Selection(_ row: Int) {
        switch row {
        case 0:
            print("Game Controller Pressed")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let gameViewController = storyboard.instantiateViewController(withIdentifier: "GameView") as? GameViewController {
                gameViewController.modalPresentationStyle = .pageSheet
                present(gameViewController, animated: true, completion: nil)
            }
        default:
            break
        }
    }

    func handleSection6Selection(_ row: Int) {
        switch row {
        case 0:
            handleRow1Action()
        case 1:
            handleRow2Action()
        case 2:
            handleRow3Action()
        case 3:
            handleRow4Action()
        default:
            break
        }
    }

    func handleSection7Selection(_ row: Int) {
        switch row {
        case 0:
            if !sessionStore.isSignedIn {
                presentAuthentication()
            } else {
                sessionStore.signOut()
                presentSignOutAlert()
            }
        case 1:
            handleDeleteAccount()
        case 2:
            openURL("https://teleprompterpro2.com/terms.html")
        case 3:
            openURL("https://teleprompterpro2.com/privacy.html")
        default:
            break
        }
    }


    func handleRow1Action() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        } else {
            print("Failed to get the window scene for requesting a review.")
        }
    }

    func handleRow2Action() {
        let nextVC = PaywallViewController()
        nextVC.delegate = self
        present(nextVC, animated: true, completion: nil)
        print("Row 2 in section 4 selected")
    }

    func handleRow3Action() {
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertController(title: "Mail Services Unavailable", message: "This device cannot send emails. Please configure an email account in the Mail app.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }

        let mailComposeVC = MFMailComposeViewController()
        mailComposeVC.mailComposeDelegate = self
        mailComposeVC.setToRecipients(["hello@mattcowlin.com.com"])
        mailComposeVC.setSubject("TeleprompterX Support Request")
        self.present(mailComposeVC, animated: true, completion: nil)
        print("Row 3 in section 4 selected")
    }

    func handleRow4Action() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let suggestFeatureController = storyboard.instantiateViewController(withIdentifier: "SuggestFeatures") as? SuggestFeatureViewController {
            suggestFeatureController.modalPresentationStyle = .pageSheet
            present(suggestFeatureController, animated: true, completion: nil)
        }
    }


    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func presentBackgroundAudioOptions() {
        let alert = UIAlertController(title: "Background Audio for Picture in Picture", message: "Select an option", preferredStyle: .actionSheet)
        for option in BackgroundAudioOption.allCases {
            alert.addAction(UIAlertAction(title: option.rawValue, style: .default, handler: { [weak self] _ in
                self?.selectedBackgroundAudio = option
                self?.tableView.reloadData()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func handleDeleteAccount() {
        let alertController = UIAlertController(
            title: "Delete Account",
            message: "Are you sure you want to delete your account? This action will sign you out immediately and delete your saved scripts in the Cloud.",
            preferredStyle: .alert
        )

        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performAccountDeletion()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    private func performAccountDeletion() {
        guard let user = Auth.auth().currentUser else {
            presentAlert(title: "Error", message: "No user is currently signed in.")
            return
        }

        FirebaseManager.shared.deleteAllScripts { [weak self] error in
            if let error = error {
                self?.presentAlert(title: "Error", message: "Failed to delete scripts: \(error.localizedDescription)")
                return
            }

            user.delete { [weak self] error in
                if let error = error {
                    self?.presentAlert(title: "Error", message: "Failed to delete account: \(error.localizedDescription)")
                } else {
                    self?.sessionStore.signOut()
                    self?.presentAlert(title: "Account Deleted", message: "Your account has been successfully deleted.")
                }
            }
        }
    }

  

    @objc func alignmentSegmentedControlValueChanged(_ segmentedControl: UISegmentedControl) {
        let alignment: NSTextAlignment
        switch segmentedControl.selectedSegmentIndex {
        case 0: alignment = .left
        case 1: alignment = .center
        case 2: alignment = .right
        default: alignment = .left
        }

        UserDefaults.standard.set(segmentedControl.selectedSegmentIndex, forKey: "TextAlignment")
        delegate?.didSelectTextAlignment(alignment)
    }

    func setupHeaderButtons() {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))
        headerView.backgroundColor = .clear

        let settingsButton = UIButton(type: .system)
        settingsButton.setImage(UIImage(systemName: "gear"), for: .normal)
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(settingsButton)
        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            settingsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(doneButton)
        NSLayoutConstraint.activate([
            doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])

        tableView.tableHeaderView = headerView
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))
        headerView.backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)

        let sectionSymbols: [Int: String] = [
            0: "🎉",
            1: "textformat.alt",
            2: "square.and.line.vertical.and.square",
            3: "gauge.open.with.lines.needle.33percent",
            4: "rectangle.on.rectangle", // Symbol for Displays section
            5: "gamecontroller",
            6: "info.circle",
            7: "person.crop.circle"
        ]

        switch section {
        case 0: // Check if the user has upgraded
           
                titleLabel.text = "Share this App"
            
        case 1: titleLabel.text = "Formatting"
        case 2: titleLabel.text = "Spacing"
        case 3: titleLabel.text = "Controls"
        case 4: titleLabel.text = "Displays" // New section header
        case 5: titleLabel.text = "Wireless Command"
        case 6: titleLabel.text = "From the Developers"
        case 7: titleLabel.text = "Account"
        default: break
        }

        if let symbolName = sectionSymbols[section] {
            let symbolImageView = UIImageView(image: UIImage(systemName: symbolName))
            symbolImageView.translatesAutoresizingMaskIntoConstraints = false
            headerView.addSubview(symbolImageView)

            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
                titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

                symbolImageView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
                symbolImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                symbolImageView.heightAnchor.constraint(equalToConstant: symbolImageView.intrinsicContentSize.height),
                symbolImageView.widthAnchor.constraint(equalToConstant: symbolImageView.intrinsicContentSize.width)
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
                titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
            ])
        }

        return headerView
    }


    func userHasUpgraded() -> Bool {
        var hasUpgraded = false
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if customerInfo?.entitlements["Pro Upgrade"]?.isActive == true {
                hasUpgraded = true
            }
        }
        return hasUpgraded
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50 // Set the height of the header view
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 88 // Double the height of standard cells
        }
        if indexPath.section == 4 && indexPath.row == 0 {
                return UITableView.automaticDimension
            }
        return 44 // Default height for other cells
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 4 && indexPath.row == 0 {
            return 100 // Estimated height for the custom cell
        }
        return 44 // Default height for other cells
    }

    func presentFontPicker() {
        let fontPicker = UIFontPickerViewController()
        fontPicker.delegate = self
        present(fontPicker, animated: true, completion: nil)
    }

    @objc func timedSpeechSwitchToggled(_ timedSpeechSwitch: UISwitch) {
        timedSpeechEnabled = timedSpeechSwitch.isOn
        tableView.reloadData()
        delegate?.didToggleTimedSpeechMode(timedSpeechEnabled)
    }

    @objc func timedSpeechStepperValueChanged(_ stepper: UIStepper) {
        timedSpeechTime = stepper.value
        UserDefaults.standard.set(timedSpeechTime, forKey: "TimedSpeechTime")
        NotificationCenter.default.post(name: NSNotification.Name("TimedSpeechTimeDidChange"), object: nil, userInfo: ["NewTime": timedSpeechTime])
        delegate?.didChangeTimedSpeechTime(timedSpeechTime)
    }

    @objc func eyeFocusModeToggled(_ toggleSwitch: UISwitch) {
        eyeFocusEnabled = toggleSwitch.isOn
        UserDefaults.standard.set(eyeFocusEnabled, forKey: "EyeFocusEnabled")
        delegate?.didToggleEyeFocusMode(eyeFocusEnabled)
    }

    @objc func cueModeToggled(_ toggleSwitch: UISwitch) {
        print("Cue mode switch pressed")
        cueEnabled = toggleSwitch.isOn
        UserDefaults.standard.set(cueEnabled, forKey: "cueEnabled")
        NotificationCenter.default.post(name: .cueModeToggled, object: nil, userInfo: ["isEnabled": cueEnabled])
        delegate?.didToggleCueMode(isEnabled: cueEnabled)
    }

    @objc func reverseModeToggled(_ toggleSwitch: UISwitch) {
        reverseModeEnabled = toggleSwitch.isOn
        UserDefaults.standard.set(reverseModeEnabled, forKey: "ReverseModeEnabled")
        delegate?.didToggleReverseMode(_isEnabled: reverseModeEnabled)
    }

    @objc func fontSizeStepperValueChanged(_ stepper: UIStepper) {
        let fontSize = CGFloat(stepper.value)
        currentFontSize = fontSize
        delegate?.didChangeFontSize(fontSize)
        
        // Ensure correct section and row for Font Size Cell
        let fontSizeIndexPath = IndexPath(row: 2, section: 1)
        if let cell = tableView.cellForRow(at: fontSizeIndexPath),
           let fontSizeLabel = cell.contentView.viewWithTag(100) as? UILabel {
            fontSizeLabel.text = "\(Int(fontSize))"
        }
    }


    func checkPremiumStatus() {
        Purchases.shared.getCustomerInfo { (customerInfo, error) in
            if customerInfo?.entitlements.all["Pro Upgrade"]?.isActive == true {
                print("Customer has upgraded")
                self.hasTheUserUpgraded = true
            } else {
                print("Customer has NOT upgraded")
                self.hasTheUserUpgraded = false
            }
        }
    }
}

extension SettingsViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        let selectedColor = viewController.selectedColor
        if let indexPath = selectedIndexPath {
            switch (indexPath.section, indexPath.row) {
            case (3, 9): // Highlight Line
                UserDefaults.standard.highlightLineColor = selectedColor
                if let cell = tableView.cellForRow(at: indexPath),
                   let colorView = cell.contentView.viewWithTag(3) {
                    colorView.backgroundColor = selectedColor
                }
                delegate?.didChangeHighlightLineColor(selectedColor)
            case (1, 0): // Background Color
                UserDefaults.standard.setColor(selectedColor, forKey: "BackgroundColor")
                if let cell = tableView.cellForRow(at: indexPath),
                   let backgroundView = cell.accessoryView as? UIView {
                    backgroundView.backgroundColor = selectedColor
                }
                delegate?.didSelectBackgroundColor(selectedColor)
            case (1, 1): // Font Color
                UserDefaults.standard.setColor(selectedColor, forKey: "FontColor")
                if let cell = tableView.cellForRow(at: indexPath),
                   let fontView = cell.accessoryView as? UIView {
                    fontView.backgroundColor = selectedColor
                }
                delegate?.didSelectFontColor(selectedColor)
            default:
                break
            }
        }
        viewController.dismiss(animated: true, completion: nil)
    }
}




extension UserDefaults {
    func color(forKey key: String) -> UIColor? {
        guard let hexString = string(forKey: key) else { return nil }
        return UIColor(hexString: hexString)
    }
}

extension UIColor {
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format:"#%06x", rgb)
    }
    
    convenience init?(hexString: String) {
        var hexSanitized = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexString.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        self.init(red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgb & 0x0000FF) / 255.0,
                  alpha: 1.0)
    }
}


extension SettingsViewController: UIFontPickerViewControllerDelegate {
    func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
        guard let selectedFontDescriptor = viewController.selectedFontDescriptor else { return }
        let selectedFont = UIFont(descriptor: selectedFontDescriptor, size: currentFontSize)
        delegate?.didSelectFont(selectedFont)
        tableView.reloadData()
    }
}

extension SettingsViewController {
    func formattedTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController: PaywallViewControllerDelegate {
    func paywallViewController(_ controller: PaywallViewController, didFinishPurchasingWith customerInfo: CustomerInfo) {
        checkPremiumStatus()
    }
}

extension SettingsViewController: MarginSettingsVisibilityDelegate {
    func didPresentMarginSettings() {
        view.alpha = 0.0
    }

    func didDismissMarginSettings() {
        view.alpha = 1.0
    }

    func didUpdateMargins(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        if let viewController = presentingViewController as? ViewController {
            viewController.textView.textContainerInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            viewController.saveMarginsToDefaults(top: top, bottom: bottom, left: left, right: right)
            
            
        }
        
    }


}
extension UserDefaults {
    @objc dynamic var highlightLineNumber: Int {
        get {
            let number = integer(forKey: "HighlightLineNumber")
            return number == 0 ? 4 : number // Default to 4 if not set
        }
        set { set(newValue, forKey: "HighlightLineNumber") }
    }

    @objc dynamic var highlightLineColor: UIColor {
        get {
            if let colorData = data(forKey: "HighlightLineColor"),
               let color = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(colorData) as? UIColor {
                return color
            }
            return .red // Default color
        }
        set {
            let colorData = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false)
            set(colorData, forKey: "HighlightLineColor")
        }
    }

    @objc dynamic var highlightLineEnabled: Bool {
        get { return bool(forKey: "HighlightLineEnabled") }
        set { set(newValue, forKey: "HighlightLineEnabled") }
    }
}


extension UserDefaults {
    
    func setColor(_ color: UIColor?, forKey key: String) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: color ?? UIColor.clear, requiringSecureCoding: false)
        set(data, forKey: key)
    }
}

