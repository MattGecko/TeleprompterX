import UIKit

class TimerSettingsCell: UITableViewCell {
    // UI elements
    let timerSwitch: UISwitch = {
        let switchControl = UISwitch()
        return switchControl
    }()
    
    let stepper: UIStepper = {
        let stepperControl = UIStepper()
        stepperControl.minimumValue = 0
        stepperControl.maximumValue = 60 // Set maximum value to 60 seconds
        stepperControl.stepValue = 1
        return stepperControl
    }()
    
    let timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        
        if UserDefaults.standard.bool(forKey: "StartTimerModeEnabled") {
            if let savedTime = UserDefaults.standard.value(forKey: "StartTimerTime") as? Double {
                let minutes = Int(savedTime) / 60
                let seconds = Int(savedTime) % 60
                let timeString = String(format: "%02d:%02d", minutes, seconds)
                label.text = timeString
            } else {
                label.text = "00:00"
                print ("No user defaults found")
            }
        }
        
        return label
    }()
    
    // Override init method
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add UI elements to contentView
        contentView.addSubview(timerSwitch)
        contentView.addSubview(stepper)
        contentView.addSubview(timeLabel)
        
        // Add constraints
        timerSwitch.translatesAutoresizingMaskIntoConstraints = false
        stepper.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            timerSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            timerSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            stepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stepper.trailingAnchor.constraint(equalTo: timerSwitch.leadingAnchor, constant: -10),
            
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -10)
        ])
        
        // Add target actions for switch and stepper
        timerSwitch.addTarget(self, action: #selector(timerSwitchValueChanged(_:)), for: .valueChanged)
        stepper.addTarget(self, action: #selector(stepperValueChanged(_:)), for: .valueChanged)
        
        // Hide timeLabel initially
        timeLabel.isHidden = !timerSwitch.isOn
        
        // Retrieve saved time from UserDefaults
            if UserDefaults.standard.bool(forKey: "StartTimerModeEnabled") {
                timeLabel.isHidden = false
                if let savedTime = UserDefaults.standard.value(forKey: "StartTimerTime") as? Double {
                    let minutes = Int(savedTime) / 60
                    let seconds = Int(savedTime) % 60
                    let timeString = String(format: "%02d:%02d", minutes, seconds)
                    timeLabel.text = timeString
                } else {
                    timeLabel.text = "00:00"
                }
            }
            
           
        
        // Observe notifications for timer settings changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateTimerSettings(_:)), name: NSNotification.Name("StartTimerSettingsDidChange"), object: nil)
    }
    
    
    
    // Required initializer
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    
    // Action for the timer switch value changed event
    @objc func timerSwitchValueChanged(_ sender: UISwitch) {
        // Save enabled state to UserDefaults
        UserDefaults.standard.set(sender.isOn, forKey: "StartTimerModeEnabled")
        
        // Save selected time to UserDefaults
        UserDefaults.standard.set(stepper.value, forKey: "StartTimerTime")
        
        // Hide/show timeLabel based on switch state
        timeLabel.isHidden = !sender.isOn
        
        // If switch is on, update the time label
        if sender.isOn {
            updateTimeLabel()
        }
        
        // Send notification with enabled state and selected time
        NotificationCenter.default.post(name: NSNotification.Name("StartTimerSettingsDidChange"), object: nil, userInfo: ["StartTimerModeEnabled": sender.isOn, "StartTimerTime": stepper.value])
        
    }


    
    // Action for the stepper value changed event
    @objc func stepperValueChanged(_ sender: UIStepper) {
        // Update time label
        updateTimeLabel()
        
        // Save selected time to UserDefaults
        let selectedTime = Int(sender.value) // Convert to integer
        UserDefaults.standard.set(selectedTime, forKey: "StartTimerTime")
        
        // Post the notification with both switch state and stepper value
        let switchState = UserDefaults.standard.bool(forKey: "StartTimerModeEnabled")
        NotificationCenter.default.post(name: NSNotification.Name("StartTimerSettingsDidChange"), object: nil, userInfo: ["StartTimerModeEnabled": switchState, "StartTimerTime": selectedTime])
    }

    
    // Function to update the time label based on the stepper value
    func updateTimeLabel() {
        let seconds = Int(stepper.value)
        let timeString = String(format: "%02d s", seconds)
        timeLabel.text = timeString
        
        // Post a notification with the new time
        NotificationCenter.default.post(name: NSNotification.Name("StartTimerTimeDidChange"), object: nil, userInfo: ["NewTime": seconds])
    }

    
    @objc func updateTimerSettings(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        
        // Check if start timer mode enabled key exists
        if let startTimerModeEnabled = userInfo["StartTimerModeEnabled"] as? Bool {
            // Update timer switch state and time label visibility
            timerSwitch.isOn = startTimerModeEnabled
            timeLabel.isHidden = !startTimerModeEnabled
        }
        
        // Update time label regardless of the switch state
        if let startTimerTime = userInfo["StartTimerTime"] as? Double {
            stepper.value = startTimerTime
            updateTimeLabel()
        }
    }


    
    
    
    // Remove observer when cell is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
