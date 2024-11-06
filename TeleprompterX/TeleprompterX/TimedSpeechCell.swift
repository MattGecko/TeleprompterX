import UIKit

protocol TimedSpeechCellDelegate: AnyObject {
    func didToggleTimedSpeechMode(_ isEnabled: Bool)
    func didChangeTimedSpeechTime(_ timeInSeconds: TimeInterval)
    func didToggleTimedSpeechRestriction(_ isEnabled: Bool)
}

class TimedSpeechCell: UITableViewCell {
    
    weak var delegate: TimedSpeechCellDelegate?
    
    // Define a notification name
    static let timedSpeechSwitchStateChangedNotification = Notification.Name("TimedSpeechSwitchStateChanged")
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var timedSpeechSwitch: UISwitch = {
        let timedSpeechSwitch = UISwitch()
        timedSpeechSwitch.isOn = UserDefaults.standard.bool(forKey: "TimedSpeechSwitchState") // Check UserDefaults for switch state
        timedSpeechSwitch.addTarget(self, action: #selector(timedSpeechSwitchToggled(_:)), for: .valueChanged)
        timedSpeechSwitch.translatesAutoresizingMaskIntoConstraints = false
        return timedSpeechSwitch
    }()
    
    private lazy var timedSpeechStepper: UIStepper = {
        let timedSpeechStepper = UIStepper()
        timedSpeechStepper.minimumValue = 30
        timedSpeechStepper.maximumValue = 60 * 60 // 60 minutes
        timedSpeechStepper.stepValue = 30 // 30-second intervals
        timedSpeechStepper.value = UserDefaults.standard.double(forKey: "TimedSpeechTime") // Set default time from UserDefaults
        timedSpeechStepper.isEnabled = UserDefaults.standard.bool(forKey: "TimedSpeechSwitchState") // Enable stepper based on switch state
        timedSpeechStepper.addTarget(self, action: #selector(timedSpeechStepperValueChanged(_:)), for: .valueChanged)
        timedSpeechStepper.translatesAutoresizingMaskIntoConstraints = false
        return timedSpeechStepper
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = !timedSpeechSwitch.isOn // Hide label if switch is off
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubviews() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(timedSpeechSwitch)
        contentView.addSubview(timeLabel)
        contentView.addSubview(timedSpeechStepper)
        
        // Add constraints
        timedSpeechSwitch.translatesAutoresizingMaskIntoConstraints = false
        timedSpeechStepper.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            timedSpeechSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            timedSpeechSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            timedSpeechStepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            timedSpeechStepper.trailingAnchor.constraint(equalTo: timedSpeechSwitch.leadingAnchor, constant: -10),
            
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: timedSpeechStepper.leadingAnchor, constant: -10)
        ])


        
        // Hide or show time label based on switch state
        timeLabel.isHidden = !timedSpeechSwitch.isOn
        
        // Display time label if switch is initially on
        if timedSpeechSwitch.isOn {
            let minutes = Int(timedSpeechStepper.value) / 60
            let seconds = Int(timedSpeechStepper.value) % 60
            let timeString = String(format: "%02d:%02d", minutes, seconds)
            setTimeLabelText(timeString)
        }
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
    }
    
    func setTimeLabelText(_ text: String) {
        timeLabel.text = text
    }
    
    @objc private func timedSpeechSwitchToggled(_ sender: UISwitch) {
        delegate?.didToggleTimedSpeechMode(sender.isOn)
        timedSpeechStepper.isEnabled = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: "TimedSpeechSwitchState")
        timeLabel.isHidden = !sender.isOn
        
        // If the switch is turned on, update the time label text
        if sender.isOn {
            let minutes = Int(timedSpeechStepper.value) / 60
            let seconds = Int(timedSpeechStepper.value) % 60
            let timeString = String(format: "%02d:%02d", minutes, seconds)
            setTimeLabelText(timeString)
        }
        
        // Notify the delegate about timed speech restriction change
        delegate?.didToggleTimedSpeechRestriction(sender.isOn)
        
        // Post the notification when the switch state changes
        NotificationCenter.default.post(name: TimedSpeechCell.timedSpeechSwitchStateChangedNotification, object: sender.isOn)
    }
    
    @objc private func timedSpeechStepperValueChanged(_ sender: UIStepper) {
        let minutes = Int(sender.value) / 60
        let seconds = Int(sender.value) % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        setTimeLabelText(timeString)
        let timedSpeechTime = sender.value
        
        UserDefaults.standard.set(sender.value, forKey: "TimedSpeechTime") // Store time value in UserDefaults
        // Post a notification with the new time
        NotificationCenter.default.post(name: NSNotification.Name("TimedSpeechTimeDidChange"), object: nil, userInfo: ["NewTime": timedSpeechTime])
        delegate?.didChangeTimedSpeechTime(sender.value)
    }
}
