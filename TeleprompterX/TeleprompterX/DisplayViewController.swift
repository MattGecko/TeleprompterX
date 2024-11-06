import UIKit

class DisplayViewController: UIViewController, SettingsDelegate {
    // Implementation of SettingsDelegate methods (can remain empty if not used)
    func didToggleWatermark(isEnabled: Bool) {}
    func didUpdateMargins(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {}
    func didTogglePagination(_ isEnabled: Bool) {}
    func presentMarginSettings() {}
    func didSelectBackgroundColor(_ color: UIColor) {}
    func didSelectFontColor(_ color: UIColor) {}
    func didChangeFontSize(_ fontSize: CGFloat) {}
    func didChangeLineHeight(_ lineHeight: CGFloat) {}
    func didSelectFont(_ selectedFont: UIFont) {}
    func didSelectTextAlignment(_ textAlignment: NSTextAlignment) {}
    func didToggleEyeFocusMode(_ isEnabled: Bool) {}
    func didToggleTimedSpeechMode(_ isEnabled: Bool) {}
    func didChangeTimedSpeechMode(isEnabled: Bool) {}
    func didChangeTimedSpeechTime(_ timeInterval: TimeInterval) {}
    func didToggleCueMode(isEnabled: Bool) {}
    func didToggleReverseMode(_isEnabled: Bool) {}
    func didToggleStartTimerMode(_ isEnabled: Bool) {}
    func didChangeStartTimerTime(_ timeInterval: TimeInterval) {}
    func didToggleTapToScroll(_ isEnabled: Bool) {}
    func didToggleExternalDisplay(isEnabled: Bool) {}

    private var previousVisibleLines: [String] = []
    var textView: UITextView!
    var watermarkImageView: UIImageView?
    var cueImageView: UIImageView?
    var countdownLabel: UILabel?
    var countdownView: UIView?
    var countdownTimer: Timer?
    var countdownTime: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        // Configure the textView
        textView = UITextView(frame: view.bounds)
        textView.backgroundColor = .black
        textView.textColor = .white // Adjust according to your needs
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.isSelectable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        
        view.addSubview(textView)
        // Set initial font color
        initializeFontColor()

        // Add observer for content offset changes
        textView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        
        // Add observers for highlight line changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleHighlightLineNumberChanged(_:)), name: .highlightLineNumberChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleHighlightLineColorChanged(_:)), name: .highlightLineColorChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleHighlightLineToggleChanged(_:)), name: .highlightLineToggleChanged, object: nil)
        // Add observer for cue mode
        NotificationCenter.default.addObserver(self, selector: #selector(handleCueModeToggled(_:)), name: .cueModeToggled, object: nil)
        // Add observer for margin updates
        NotificationCenter.default.addObserver(self, selector: #selector(marginsUpdated(_:)), name: NSNotification.Name("MarginsUpdated"), object: nil)
        // Add observer for watermark toggled
        NotificationCenter.default.addObserver(self, selector: #selector(handleWatermarkToggled(_:)), name: .watermarkToggled, object: nil)
        // Add observer for line height changes
        NotificationCenter.default.addObserver(self, selector: #selector(lineHeightChanged(_:)), name: .lineHeightChanged, object: nil)
        // Add observer for timer mode toggled
        NotificationCenter.default.addObserver(self, selector: #selector(handleTimerModeToggled(_:)), name: .timerModeToggled, object: nil)
        // Add observer for start scrolling
        NotificationCenter.default.addObserver(self, selector: #selector(handleStartScrolling(_:)), name: .startScrolling, object: nil)
        
        // Check watermark status on load
        checkAndDisplayWatermark()
        setupCueImageView()
        
        // Check and set cue mode status
        let cueModeEnabled = UserDefaults.standard.bool(forKey: "cueEnabled")
        updateCueMode(isEnabled: cueModeEnabled)
    }

    private func initializeFontColor() {
        // Set initial font color to white
        textView.textColor = .white
        print("Initial font color set to white in DisplayView")

        // Check and set user-specified font color
        if let fontColorHex = UserDefaults.standard.string(forKey: "FontColor"),
           let fontColor = UIColor(hexString: fontColorHex) {
            textView.textColor = fontColor
            print("User-specified font color set in DisplayView: \(fontColor)")
        }

        // Save the initial font color to UserDefaults for later use
        if let initialFontColor = textView.textColor {
            let initialFontColorHex = initialFontColor.toHexString()
            print("Saving initial font color hex in DisplayView: \(initialFontColorHex)")
            UserDefaults.standard.set(initialFontColorHex, forKey: "InitialFontColor_DisplayView")
            UserDefaults.standard.synchronize()
            print("Initial font color saved in DisplayView: \(initialFontColorHex)")
        } else {
            print("Failed to get initial font color from textView in DisplayView")
        }
    }

    @objc private func handleHighlightLineNumberChanged(_ notification: Notification) {
        if let lineNumber = notification.userInfo?["lineNumber"] as? Int {
            didChangeHighlightLineNumber(lineNumber)
        }
    }

    @objc private func handleHighlightLineColorChanged(_ notification: Notification) {
        if let color = notification.userInfo?["color"] as? UIColor {
            didChangeHighlightLineColor(color)
        }
    }

    @objc private func handleHighlightLineToggleChanged(_ notification: Notification) {
        if let isEnabled = notification.userInfo?["isEnabled"] as? Bool {
            didToggleHighlightLine(isEnabled)
            print("Line Highlight Toggled")
        }
    }

    func didChangeHighlightLineNumber(_ lineNumber: Int) {
        updateHighlightLineNumber(lineNumber)
    }

    func didChangeHighlightLineColor(_ color: UIColor) {
        updateHighlightLineColor(color)
    }

    func didToggleHighlightLine(_ isEnabled: Bool) {
        toggleHighlightLine(isEnabled)
    }

    private func updateHighlightLineNumber(_ number: Int) {
        highlightSpecifiedLine()
    }

    private func updateHighlightLineColor(_ color: UIColor) {
        highlightSpecifiedLine()
    }

    func toggleHighlightLine(_ isEnabled: Bool) {
        if isEnabled {
            print("Line Highlight Enabled in External View")
            highlightSpecifiedLine()
        } else {
            print("Line Highlight Disabled in External View")
            resetTextToInitialColor()
            print("Should be resetting color")
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            let currentVisibleLines = textView.visibleLines()
            if linesHaveChanged(previousLines: previousVisibleLines, currentLines: currentVisibleLines) {
                previousVisibleLines = currentVisibleLines
                printVisibleLines(lines: currentVisibleLines)
                highlightSpecifiedLine()
            }
        }
    }

    private func linesHaveChanged(previousLines: [String], currentLines: [String]) -> Bool {
        guard previousLines.count == currentLines.count else { return true }
        
        for (previousLine, currentLine) in zip(previousLines, currentLines) {
            if previousLine != currentLine {
                return true
            }
        }
        
        return false
    }

    private func printVisibleLines(lines: [String]) {
        for (index, line) in lines.enumerated() {
            //  print("Line \(index + 1): \(line)")
        }
    }

    private func highlightSpecifiedLine() {
        guard let highlightLineNumber = UserDefaults.standard.value(forKey: "highlightLineNumber") as? Int,
              let highlightColorData = UserDefaults.standard.data(forKey: "highlightLineColor"),
              let highlightLineColor = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(highlightColorData) as? UIColor else {
            print("Guard statement failed.")
            return
        }
        
        guard let initialFontColorHex = UserDefaults.standard.string(forKey: "InitialFontColor_DisplayView"),
              let initialFontColor = UIColor(hexString: initialFontColorHex) else {
            print("Initial font color not found in Display View.")
            return
        }
        
        // Check if highlight line is enabled
        let isHighlightLineEnabled = UserDefaults.standard.bool(forKey: "highlightLineEnabled")
        
        let visibleRect = textView.bounds
        let visibleGlyphRange = textView.layoutManager.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer)
        
        var currentLineNumber = 1
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
        
        textView.layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { (rect, usedRect, textContainer, glyphRange, stop) in
            let characterRange = self.textView.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineText = (self.textView.text as NSString).substring(with: characterRange)
            
            if isHighlightLineEnabled && currentLineNumber == highlightLineNumber {
                attributedString.addAttribute(.foregroundColor, value: highlightLineColor, range: characterRange)
            } else {
                attributedString.addAttribute(.foregroundColor, value: initialFontColor, range: characterRange)
            }
            currentLineNumber += 1
        }
        
        // Apply the updated attributed string to the text view
        textView.attributedText = attributedString
        print("Updated attributed text applied to textView.")
    }


    private func resetTextToInitialColor() {
        guard let initialFontColorHex = UserDefaults.standard.string(forKey: "InitialFontColor_DisplayView"),
              let initialFontColor = UIColor(hexString: initialFontColorHex) else {
            print("Initial font color not found in Display View Reset Call.")
            return
        }

        print("Initial font color found in Display View: \(initialFontColor)")

        let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
        let fullRange = NSRange(location: 0, length: attributedString.length)

        print("Full range in Display View: \(fullRange)")

        attributedString.addAttribute(.foregroundColor, value: initialFontColor, range: fullRange)

        DispatchQueue.main.async {
            // Apply the updated attributed string to the text view
            self.textView.attributedText = attributedString
            self.textView.setNeedsDisplay()
            self.textView.layoutIfNeeded()

            print("Reset text color to initial font color in Display View.")
        }
    }


    @objc private func handleTimerModeToggled(_ notification: Notification) {
        print("handleTimerModeToggled called")
        guard let userInfo = notification.userInfo,
              let isEnabled = userInfo["isEnabled"] as? Bool else {
            print("Failed to get userInfo from notification")
            return
        }
        print("Timer mode isEnabled: \(isEnabled)")
        if isEnabled {
            showCountdownView()
        } else {
            hideCountdownView()
        }
    }

    @objc private func handleStartScrolling(_ notification: Notification) {
        print("handleStartScrolling called")
        showCountdownView()
        startCountdown()
    }

    func showCountdownView() {
        if countdownView == nil {
            // Create countdown view
            let countdownView = UIView()
            countdownView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            countdownView.layer.cornerRadius = 20
            countdownView.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(countdownView)

            // Add constraints to position and size the background view
            NSLayoutConstraint.activate([
                countdownView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                countdownView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                countdownView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 7/8),
                countdownView.heightAnchor.constraint(equalToConstant: 200) // Adjust height as needed
            ])

            // Create countdown label
            let label = UILabel()
            label.font = UIFont(name: "Impact", size: 100)
            label.textColor = .white
            label.textAlignment = .center
            label.text = String(format: "%02d", countdownTime % 60)
            label.translatesAutoresizingMaskIntoConstraints = false
            countdownView.addSubview(label)
            countdownLabel = label

            // Add constraints to center the label within the background view
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: countdownView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: countdownView.centerYAnchor),
                label.widthAnchor.constraint(equalTo: countdownView.widthAnchor),
                label.heightAnchor.constraint(equalTo: countdownView.heightAnchor)
            ])

            // Store reference to countdown view
            self.countdownView = countdownView

            // Make the countdown view draggable
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            countdownView.addGestureRecognizer(panGesture)

            print("Countdown view shown")
        }

        // Reset countdown time to the newly selected time
        countdownTime = Int(UserDefaults.standard.double(forKey: "StartTimerTime"))

        // Update countdown label text
        countdownLabel?.text = String(format: "%02d", countdownTime % 60)

        print("Countdown outside block is called")
    }

    func startCountdown() {
        if countdownTimer == nil {
            // Start the countdown timer
            countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
            print("Countdown started")
        }
    }

    func hideCountdownView() {
        countdownView?.removeFromSuperview()
        countdownLabel = nil
        countdownView = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        print("Countdown view hidden")
    }

    @objc func updateCountdown() {
        guard countdownTime > 1 else { // Check if the countdown time is greater than 1
            countdownTimer?.invalidate()
            countdownTimer = nil
            hideCountdownView() // Hide the countdown view before updating the label to avoid showing 0
            return
        }
        countdownTime -= 1
        countdownLabel?.text = String(format: "%02d", countdownTime % 60)
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let countdownView = gesture.view else { return }
        let translation = gesture.translation(in: view)
        countdownView.center = CGPoint(x: countdownView.center.x + translation.x, y: countdownView.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
    }

    func setupCueImageView() {
        let cueImage = UIImage(named: "cue")
        cueImageView = UIImageView(image: cueImage)
        if let cueImageView = cueImageView {
            cueImageView.translatesAutoresizingMaskIntoConstraints = false
            cueImageView.contentMode = .scaleAspectFit
            view.addSubview(cueImageView)
            
            NSLayoutConstraint.activate([
                cueImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cueImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                cueImageView.widthAnchor.constraint(equalToConstant: cueImage?.size.width ?? 50), // Adjust width as needed
                cueImageView.heightAnchor.constraint(equalToConstant: cueImage?.size.height ?? 50) // Adjust height as needed
            ])
            cueImageView.isHidden = true
        }
    }

    @objc private func handleCueModeToggled(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isEnabled = userInfo["isEnabled"] as? Bool else { return }
        updateCueMode(isEnabled: isEnabled)
    }

    func updateCueMode(isEnabled: Bool) {
        if isEnabled {
            print("Cue enabled on external screen")
            cueImageView?.isHidden = false
            let cueWidth = cueImageView?.frame.width ?? 0
            textView.textContainerInset.left = cueWidth
            textView.textContainerInset.right = cueWidth
        } else {
            cueImageView?.isHidden = true
            textView.textContainerInset.left = 0
            textView.textContainerInset.right = 0
            print("Cue disabled on external screen")
        }
    }

    func checkAndDisplayWatermark() {
        let isWatermarkEnabled = UserDefaults.standard.bool(forKey: "WatermarkEnabled")
        updateWatermark(isEnabled: isWatermarkEnabled)
    }

    func updateWatermark(isEnabled: Bool) {
        print("Updating watermark display: \(isEnabled)")
        if isEnabled {
            if watermarkImageView == nil {
                let watermarkImage = UIImage(named: "watermark")
                watermarkImageView = UIImageView(image: watermarkImage)
                if let watermarkImageView = watermarkImageView {
                    watermarkImageView.translatesAutoresizingMaskIntoConstraints = false
                    watermarkImageView.contentMode = .scaleAspectFit
                    watermarkImageView.alpha = 0.8
                    watermarkImageView.layer.cornerRadius = 10 // Adjust the radius as needed
                    watermarkImageView.layer.masksToBounds = true // Ensure corners are clipped
                    view.addSubview(watermarkImageView)
                    NSLayoutConstraint.activate([
                        watermarkImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                        watermarkImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
                        watermarkImageView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 2), // Adjust the multiplier as needed
                        watermarkImageView.heightAnchor.constraint(equalTo: watermarkImageView.widthAnchor, multiplier: (watermarkImage?.size.height ?? 1) / (watermarkImage?.size.width ?? 1)) // Maintain aspect ratio
                    ])
                }
            }
            watermarkImageView?.isHidden = false
        } else {
            watermarkImageView?.isHidden = true
        }
    }

    deinit {
        print("DisplayViewController deinitialized")

        NotificationCenter.default.removeObserver(self)
        print("Removed all observers")
        
        textView.removeObserver(self, forKeyPath: "contentOffset")
        print("Removed contentOffset observer")

        // Invalidate timers if they exist
        countdownTimer?.invalidate()
        countdownTimer = nil
        print("Invalidated countdownTimer")
        
        print("DisplayViewController deinit complete")
    }


    var externalWindow: UIWindow?

    @objc private func marginsUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let top = userInfo["top"] as? CGFloat,
              let bottom = userInfo["bottom"] as? CGFloat,
              let left = userInfo["left"] as? CGFloat,
              let right = userInfo["right"] as? CGFloat else { return }
        print("Update Margins called on External Display")
        saveMarginsToDefaults(top: top, bottom: bottom, left: left, right: right)
        print("Bottom = ", bottom)
    }

    @objc private func lineHeightChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let lineHeight = userInfo["lineHeight"] as? CGFloat else { return }
        
        print("Line height changed on External Display")
        didChangeExternalLineHeight(lineHeight)
    }

    func didChangeExternalLineHeight(_ lineHeight: CGFloat) {
        // Ensure textView.font is not nil
        guard let font = textView.font else {
            print("Font is nil")
            return
        }
        
        // Calculate the font's line height based on the current font and font size
        let fontLineHeight = font.lineHeight
        
        // Calculate the line spacing based on the difference between the desired line height and the font's line height
        let lineSpacing = lineHeight - fontLineHeight
        
        // Debug statements
        print("Line height adjusted. New line spacing: \(lineSpacing)")
        print("Line height: \(lineHeight)")
        print("Font line height: \(fontLineHeight)")
        
        // Update the paragraph style for the entire text range
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        mutableAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableAttributedString.length))
        
        // Update the attributed text of the text view
        textView.attributedText = mutableAttributedString
        
        // Load and apply text alignment
        let textAlignmentIndex = UserDefaults.standard.integer(forKey: "TextAlignment")
        let textAlignment: NSTextAlignment
        switch textAlignmentIndex {
        case 0:
            textAlignment = .left
        case 1:
            textAlignment = .center
        case 2:
            textAlignment = .right
        default:
            textAlignment = .left
        }
        textView.textAlignment = textAlignment
        
        // Save the line height to UserDefaults
        UserDefaults.standard.set(lineSpacing, forKey: "LineSpacing")
    }

    @objc private func handleWatermarkToggled(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let isEnabled = userInfo["isEnabled"] as? Bool else { return }
        print("Watermark toggled: \(isEnabled)")
        // Placeholder function to handle watermark toggle
        updateWatermark(isEnabled: isEnabled)
    }

    func saveMarginsToDefaults(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        textView.textContainerInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        adjustTextViewHeightAndPosition(for: textView, top: top, bottom: bottom)
        print("Margins called on External Display")
    }

    private func adjustTextViewHeightAndPosition(for textView: UITextView, top: CGFloat, bottom: CGFloat) {
        // Debugging statement to check if externalWindow is set
        print("adjustTextViewHeightAndPosition called")
        if externalWindow == nil {
            print("externalWindow is nil")
            return
        }
        
        guard let screen = externalWindow?.screen else {
            print("externalWindow.screen is nil")
            return
        }

        print("Screen bounds: \(screen.bounds)")

        var newFrame = textView.frame
        let screenHeight = screen.bounds.height

        // Adjust the y-position based on the top margin
        newFrame.origin.y = top

        // Adjust the height based on the top and bottom margins
        newFrame.size.height = screenHeight - top - bottom

        // Apply the new frame
        textView.frame = newFrame

        print("Adjusted textView frame: \(newFrame)")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        textView.frame = view.bounds
    }
}

extension Notification.Name {
    static let watermarkToggled = Notification.Name("watermarkToggled")
    static let lineHeightChanged = Notification.Name("lineHeightChanged")
    static let cueModeToggled = Notification.Name("cueModeToggled")
    static let timerModeToggled = Notification.Name("timerModeToggled")
    static let startScrolling = Notification.Name("startScrolling")
    static let highlightLineNumberChanged = Notification.Name("highlightLineNumberChanged")
    static let highlightLineColorChanged = Notification.Name("highlightLineColorChanged")
    static let highlightLineToggleChanged = Notification.Name("highlightLineToggleChanged")
}
