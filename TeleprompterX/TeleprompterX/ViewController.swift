//
//  ViewController.swift
//  TeleprompterX
//
//  Created by Matt Cowlin on 24/04/2024.
//
import UIKit
import UIPiPView
import AVKit
import AVFoundation
import Photos
import MobileCoreServices
import UniformTypeIdentifiers
import AEXML
import ZIPFoundation
import XMLCoder
import PDFKit
import RevenueCat
import RevenueCatUI
import SwiftUI
import GameController
import StoreKit
import Speech
import CoreImage
import QuartzCore
import GoogleMobileAds

class ViewController: UIViewController, SettingsDelegate, TimedSpeechCellDelegate, UITextViewDelegate, UIScrollViewDelegate,  UIDocumentPickerDelegate   {
    func didToggleWatermark(isEnabled: Bool) {
        print ("Watermark toggled")
        // Post notification to update DisplayViewController
            NotificationCenter.default.post(name: .watermarkToggled, object: nil, userInfo: [
                "isEnabled": isEnabled
            ])
    }
    
    //HIGHLIGHT LINE
    func didChangeHighlightLineNumber(_ lineNumber: Int) {
          updateHighlightLineNumber(lineNumber)
      }
      
      func didChangeHighlightLineColor(_ color: UIColor) {
          updateHighlightLineColor(color)
      }
      
      func didToggleHighlightLine(_ isEnabled: Bool) {
          toggleHighlightLine(isEnabled)
      }
      
    func updateHighlightLineNumber(_ number: Int) {
        UserDefaults.standard.set(number, forKey: "highlightLineNumber")
        NotificationCenter.default.post(name: .highlightLineNumberChanged, object: nil, userInfo: ["lineNumber": number])
    //    highlightSpecifiedLine()
        print("Number changed to ", number)
    }

    func updateHighlightLineColor(_ color: UIColor) {
        let colorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        UserDefaults.standard.set(colorData, forKey: "highlightLineColor")
        NotificationCenter.default.post(name: .highlightLineColorChanged, object: nil, userInfo: ["color": color])
     //   highlightSpecifiedLine()
        print("Highlight color is", color)
    }

    func toggleHighlightLine(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: "highlightLineEnabled")
        NotificationCenter.default.post(name: .highlightLineToggleChanged, object: nil, userInfo: ["isEnabled": isEnabled])
        if isEnabled {
            highlightSpecifiedLine()
        } else {
            resetTextToInitialColor()
        }
        print("Highlight Line is ", isEnabled)
    }


    private func resetTextToInitialColor() {
        guard let initialFontColorHex = UserDefaults.standard.string(forKey: "InitialFontColor"),
              let initialFontColor = UIColor(hexString: initialFontColorHex) else {
            print("Initial font color not found.")
            return
        }
        
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        attributedString.addAttribute(.foregroundColor, value: initialFontColor, range: fullRange)
        
        // Apply the updated attributed string to the text view
        textView.attributedText = attributedString
        print("Reset text color to initial font color.")
    }
    
    func updateAdVisibility() {
        guard let adConfig = adConfig else {
            // Default to showing ads if config is unavailable
            loadInterstitialAd()
            return
        }

        func loadInterstitialAd() {
            let request = GADRequest()
            //REAL KEY ca-app-pub-3785918208569837/8847847017
            
//            TEST KEY ca-app-pub-3940256099942544/4411468910
            
            GADInterstitialAd.load(withAdUnitID: "ca-app-pub-3785918208569837/8847847017", request: request) { [weak self] ad, error in
                if let error = error {
                    print("Failed to load interstitial ad: \(error)")
                    return
                }
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                self?.showInterstitialAd() // Show the ad once loaded
            }
        }

        func showInterstitialAd() {
            if let interstitialAd = interstitialAd {
                interstitialAd.present(fromRootViewController: self)
            } else {
                print("Interstitial ad was not ready to be shown.")
            }
        }

        // Check premium status and the remote config
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            
            let isUpgraded = customerInfo?.entitlements["Pro Upgrade"]?.isActive == true
            
            // Show interstitial ad if allowed by config and not upgraded
            if !isUpgraded && adConfig.showInterstitialAd {
                loadInterstitialAd()
            }
        }
    }

    
    
    //EXTERNAL DISPLAY
    var externalWindow: UIWindow?
    private var interstitialAd: GADInterstitialAd?
    
    @objc func screenDidConnect(_ notification: Notification) {
          if let screen = notification.object as? UIScreen {
              setupExternalScreen(screen)
          }
      }

      @objc func screenDidDisconnect(_ notification: Notification) {
          externalWindow?.isHidden = true
          externalWindow = nil
      }
    
    private func setupExternalScreen(screen: UIScreen, shouldRecurse: Bool = true) {
        print("Setting up external screen with bounds: \(screen.bounds)")
        let externalDisplayViewController = DisplayViewController()

        // For iOS13 find matching UIWindowScene
        var matchingWindowScene: UIWindowScene? = nil
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            for aScene in scenes {
                if let windowScene = aScene as? UIWindowScene {
                    // Look for UIWindowScene that has matching screen
                    if (windowScene.screen == screen) {
                        matchingWindowScene = windowScene
                        break
                    }
                }
            }
            if matchingWindowScene == nil {
                // UIWindowScene has not been created by iOS rendered yet
                // Lets recall self after delay of two seconds
                if true == shouldRecurse {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                        self.setupExternalScreen(screen:screen, shouldRecurse: false)
                    }
                }
                // Dont proceed furthure in iOS13
                return
            }
        }

        // Create a new window for the external screen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            externalWindow = UIWindow(windowScene: windowScene)
            externalWindow?.frame = screen.bounds
            externalWindow?.rootViewController = externalDisplayViewController
            externalWindow?.isHidden = false
        }
        
        
        // Sync the content of the main textView with the external display textView
        syncTextViewFormatting(externalDisplayViewController.textView)
        
        // Observe changes to sync with the external display
        textView.delegate = self

        if #available(iOS 13.0, *) {
            // Set windowScene here, no need to set screen
            externalWindow!.windowScene = matchingWindowScene
        } else {
            // Set screen the traditional way
            externalWindow!.screen = screen
        }
        externalWindow!.isHidden = false
        externalDisplayViewController.externalWindow = externalWindow
    }

    func syncExternalTextView() {
        if isExternalScreenEnabled {
            print("External display is enabled")
            if let externalVC = externalWindow?.rootViewController as? DisplayViewController {
                syncTextViewFormatting(externalVC.textView)
            } else {
                print("Failed to find external display view controller")
            }
        } else {
            print("External display is disabled")
            // NO NEED TO SYNC AS IT'S NOT TURNED ON
        }
    }
    func setupExternalScreen(_ screen: UIScreen) {
           print("Setting up external screen with bounds: \(screen.bounds)")
           let externalDisplayViewController = DisplayViewController()
           
           // Create a new window for the external screen
           if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
               externalWindow = UIWindow(windowScene: windowScene)
               externalWindow?.frame = screen.bounds
               externalWindow?.rootViewController = externalDisplayViewController
               externalWindow?.isHidden = false
           }
           
           // Sync the content of the main textView with the external display textView
           syncTextViewFormatting(externalDisplayViewController.textView)
           
           // Observe changes to sync with the external display
           textView.delegate = self
       }
    
    var  isExternalScreenEnabled: Bool = false
    
      // Implement the SettingsDelegate method
    func didToggleExternalDisplay(isEnabled: Bool) {
            if isEnabled, let screen = UIScreen.screens.last, screen != UIScreen.main {
                isExternalScreenEnabled = true
                setupExternalScreen(screen: screen, shouldRecurse: true)
                print("External Display Toggled ON")
            } else {
                isExternalScreenEnabled = false
                externalWindow?.isHidden = true
                externalWindow = nil
                print("External Display Toggled OFF")
            }
        }
    
    override func viewWillDisappear(_ animated: Bool) {
           super.viewWillDisappear(animated)
           // Turn off the external display when leaving the view
           isExternalScreenEnabled = false
           externalWindow?.isHidden = true
           externalWindow = nil
           UserDefaults.standard.set(false, forKey: "ExternalDisplayEnabled") // Reset the state
           print("External Display Toggled OFF")
       }
    
    

    func syncTextViewFormatting(_ targetTextView: UITextView) {
       
        targetTextView.text = textView.text
        targetTextView.font = textView.font
        targetTextView.textColor = textView.textColor
        targetTextView.backgroundColor = textView.backgroundColor
        targetTextView.textAlignment = textView.textAlignment
        targetTextView.textContainerInset = textView.textContainerInset
        targetTextView.textContainer.lineFragmentPadding = textView.textContainer.lineFragmentPadding
        
        let topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin"))
        let bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
        let leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
        let rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))

        adjustTextViewHeightAndPosition(for: targetTextView, top: topMargin, bottom: bottomMargin)
        targetTextView.textContainerInset = UIEdgeInsets(top: topMargin, left: leftMargin, bottom: bottomMargin, right: rightMargin)
        
        // Apply the same transform as the main textView
        targetTextView.transform = textView.transform

        print("TextView formatting synced to external display")
    }

      func textViewDidChange(_ textView: UITextView) {
          if let externalVC = externalWindow?.rootViewController as? DisplayViewController {
              externalVC.textView.text = textView.text
              print("TextView content changed and synced to external display")
          }
      }

      func textViewDidScroll(_ textView: UITextView) {
          if let externalVC = externalWindow?.rootViewController as? DisplayViewController {
              externalVC.textView.contentOffset = textView.contentOffset
              print("TextView scrolled and synced to external display")
          }
      }

      func textViewDidChangeSelection(_ textView: UITextView) {
          if let externalVC = externalWindow?.rootViewController as? DisplayViewController {
              externalVC.textView.selectedRange = textView.selectedRange
          }
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) {
          if scrollView == textView {
              if let externalVC = externalWindow?.rootViewController as? DisplayViewController {
                  externalVC.textView.contentOffset = textView.contentOffset
              }
          }
      }
   
    
    //TAP TO SCROLL
    func didToggleTapToScroll(_ isEnabled: Bool) {
        // Handle the state change in ViewController
        if isEnabled {
            print("Tap to Scroll is enabled")
            isTapToScrollEnabled = true
           
        } else {
            print("Tap to Scroll is disabled")
            isTapToScrollEnabled = false
           
        }
        // Save the state to UserDefaults
        UserDefaults.standard.set(isEnabled, forKey: "isTapToScrollEnabled")
    }
    
    func applyTapToScrollState(isEnabled: Bool) {
        if isEnabled {
            // Add your code to enable "Tap to Scroll"
            print("Tap to Scroll is enabled from UserDefaults")
            isTapToScrollEnabled = true
        } else {
            // Add your code to disable "Tap to Scroll"
            print("Tap to Scroll is disabled from UserDefaults")
            isTapToScrollEnabled = false
        }
    }

    
    //PAGINATION
    var paginationTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    var isPaginationEnabled = false
    var currentPage = 0
    var pages: [NSRange] = []
    private var isOnLastPage = false
  

    func didTogglePagination(_ isEnabled: Bool) {
        isPaginationEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: "isPaginationEnabled")
        currentPage = 0
        isOnLastPage = false // Reset the flag
        if isPaginationEnabled {
            print("Turned on pagination")
            textView.isScrollEnabled = true
            textView.isHidden = false
            let topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin"))
            let bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
            let leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
            let rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))
            
            let adjustedBottomMargin = bottomMargin < 220 ? 220 : bottomMargin
            adjustTextViewHeightAndPosition(for: textView, top: topMargin, bottom: adjustedBottomMargin)
            textView.textContainerInset = UIEdgeInsets(top: 0, left: leftMargin, bottom: 0, right: rightMargin)
            
            paginateText()
            updatePlayButton()
        } else {
            loadMarginsFromDefaults()
            updatePlayButton()
        }
    }

    func paginateText() {
        // This function is now responsible for scrolling to the next non-visible line
        guard let attributedText = textView.attributedText else {
            print("No attributed text found")
            return
        }

        let visibleRect = textView.convert(textView.bounds, to: textView.textInputView)
        let visibleRange = textView.characterRange(at: visibleRect.origin)

        guard let visibleStartPosition = visibleRange?.start else {
            print("Could not determine visible start position")
            return
        }

        let visibleStartIndex = textView.offset(from: textView.beginningOfDocument, to: visibleStartPosition)
        print("Visible start index: \(visibleStartIndex)")

        let newPosition = textView.position(from: visibleStartPosition, offset: 1)

        if let newPosition = newPosition {
            let newRange = textView.textRange(from: newPosition, to: newPosition)
            textView.scrollRangeToVisible(NSRange(location: visibleStartIndex + 1, length: 1))
        }
    }

    @objc func nextPage() {
        guard isPaginationEnabled else { return }

        let currentOffset = textView.contentOffset
        let visibleHeight = textView.bounds.height - textView.textContainerInset.top - textView.textContainerInset.bottom

        // Calculate the next offset
        let nextOffset = CGPoint(x: currentOffset.x, y: currentOffset.y + visibleHeight)

        // Ensure the offset does not exceed the content size
        if nextOffset.y + visibleHeight < textView.contentSize.height {
            textView.setContentOffset(nextOffset, animated: true)
            isOnLastPage = false
        } else {
            // Adjust the offset to show the last part of the text correctly
            let maxOffsetY = textView.contentSize.height - textView.bounds.height + textView.textContainerInset.bottom

            if currentOffset.y >= maxOffsetY {
                // If already on the last page, go back to the start
                textView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
                isOnLastPage = false
            } else {
                textView.setContentOffset(CGPoint(x: 0, y: maxOffsetY), animated: true)
                isOnLastPage = true
            }
        }
    }

    func updatePlayButton() {
        if isPaginationEnabled {
            playButton.setImage(UIImage(systemName: "arrow.forward"), for: .normal)
        } else {
            if isScrolling {
                playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            } else {
                playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            }
        }
    }
  
    //MARGINS
    func presentMarginSettings() {
        
    }
    
    private func adjustTextViewHeightAndPosition(for textView: UITextView, top: CGFloat, bottom: CGFloat) {
      
            var newFrame = textView.frame
            let screenHeight = UIScreen.main.bounds.height
            
            // Adjust the y-position based on the top margin
            newFrame.origin.y = top
            
            // Adjust the height based on the top and bottom margins
            newFrame.size.height = screenHeight - top - bottom
            
            // Apply the new frame
            textView.frame = newFrame
        
    }


    func saveMarginsToDefaults(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        
        if !isExternalScreenEnabled{
            UserDefaults.standard.set(top, forKey: "TopMargin")
            UserDefaults.standard.set(bottom, forKey: "BottomMargin")
            UserDefaults.standard.set(left, forKey: "LeftMargin")
            UserDefaults.standard.set(right, forKey: "RightMargin")
            
            
            
            let adjustedBottomMargin = isPaginationEnabled ? (bottom < 220 ? 220 : bottom) : bottom
            adjustTextViewHeightAndPosition(for: textView, top: top, bottom: adjustedBottomMargin)
            textView.textContainerInset = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            
            // Sync with external display if enabled
            if isExternalScreenEnabled, let externalVC = externalWindow?.rootViewController as? DisplayViewController {
                syncTextViewFormatting(externalVC.textView)
            }
        }
    }


    func didUpdateMargins(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat) {
        
        saveMarginsToDefaults(top: top, bottom: bottom, left: left, right: right)
     
              
           }
    

    @objc private func marginsUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let top = userInfo["top"] as? CGFloat,
              let bottom = userInfo["bottom"] as? CGFloat,
              let left = userInfo["left"] as? CGFloat,
              let right = userInfo["right"] as? CGFloat else { return }

        saveMarginsToDefaults(top: top, bottom: bottom, left: left, right: right)
        syncExternalTextView()
    }

    private func loadMarginsFromDefaults() {
        let topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin"))
        let bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
        let leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
        let rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))
        
        let adjustedBottomMargin = isPaginationEnabled ? (bottomMargin < 220 ? 220 : bottomMargin) : bottomMargin
        adjustTextViewHeightAndPosition(for: textView, top: topMargin, bottom: adjustedBottomMargin)
        textView.textContainerInset = UIEdgeInsets(top: topMargin, left: leftMargin, bottom: bottomMargin, right: rightMargin)

        // Sync with external display if enabled
        if isExternalScreenEnabled, let externalVC = externalWindow?.rootViewController as? DisplayViewController {
            syncTextViewFormatting(externalVC.textView)
        }
    }



    func didToggleTapToScroll(isEnabled: Bool) {
        
    }
    
    func didTogglePagination(isEnabled: Bool) {
        
    }
    
    func didChangeMargins(_ margin: CGFloat) {
        
    }
    
  
    
    private var sessionStore = SessionStore()
    var overlayView: UIView?
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var mirrorButton: UIButton!
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    var videoCaptionsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "VideoCaptionsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "VideoCaptionsEnabled") }
    }

    var isTapToScrollEnabled: Bool = false
    var currentScript: Script?
    var floatingWindowVC: FloatingWindowViewController?
    var newPip: NewUIPiPView?
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureMovieFileOutput?
    var controlsContainer: UIView!
    var alphaSlider: UISlider!
    var sizeSlider: UISlider!
    var alphaLabel: UILabel!
    var sizeLabel: UILabel!
    var closeButton: UIButton!
    var initialCountdownTime: Int = 0
    var countdownTime: Int = 0
    var countdownLabel: UILabel?
    var pausedTime: Date? // Add the pausedTime property
    var hasJustBeenReset: Bool = false
    var lastContentOffset: CGPoint?
    var lastScrollTime: TimeInterval?
    var isReplaying: Bool = false
    var isEditingText = false // Variable to track edit mode
    var scrollTimer: Timer? // Timer for scrolling text
    var scrollSpeed: Double = 50 // Initial scroll speed
    var currentLineHeight: CGFloat? //inital line height
    var selectedFont: UIFont?
    var isScrolling: Bool = false // Initially not playing
    var isReverseModeEnabled: Bool = false // Initially not reversing
    var pipView: UIPiPView?
    var pipController: AVPictureInPictureController?
    var eyeFocusEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "EyeFocusEnabled")
    }
    var isTimedSpeechEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "TimedSpeechEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TimedSpeechEnabled")
        }
    }
    // Define the symbols for recording and not recording states
    let recordingImage = UIImage(systemName: "stop.circle.fill")
    let notRecordingImage = UIImage(systemName: "video.fill.badge.plus")
    var timedSpeechTime: TimeInterval = 0.0
    var isPaused = false // Property to track if scrolling is paused
    var countdownView: UIView? // Property to hold the countdown view
    var countdownTimer: Timer? // Property to hold the countdown timer
    var selectedTimedSpeechTimeInterval: TimeInterval = 0
    var elapsedTimeView: UIView?
    var elapsedTimeLabel: UILabel?
    var elapsedTimeTimer: Timer?
    var elapsedNewTime: Int = 0
    var startTimerEnabled: Bool = false
    var startTimerTime: Double = 0.0
    var countdownTimerLabel: UILabel!
    var IntroCountdownTimer: Timer?
    var backgroundView = UIView()
    func didChangeTimedSpeechMode(isEnabled: Bool) {
        
    }
    
    func didChangeTimedSpeechTime(_ newTime: Double)  {
        // Update the timedSpeechTime variable
        
        // Convert new time to integer (assuming it's in seconds)
        let newTimeInSeconds = Int(newTime)
        
        // Update timed speech time and other related components
        updateTimedSpeechTime(newTimeInSeconds)
        
        // Calculate scroll speed based on timed speech time
        calculateScrollSpeed()
        
        // Notify the delegate about the change in timed speech time
        
    }
    
    func didToggleTimedSpeechMode(_ isEnabled: Bool) {
        // Update your variables or UI elements based on the switch state here
        isTimedSpeechEnabled = isEnabled
        updateSpeedSlider() // Call the method to update the speed slider
    }
    
    func updateSpeedSlider() {
        speedSlider.isEnabled = !isTimedSpeechEnabled
    }
    
    @objc func timedSpeechStepperValueChanged(_ stepper: UIStepper) {
        // Update the timedSpeechTime variable
        timedSpeechTime = stepper.value
        print("New timed selected = ", timedSpeechTime)
        
        // Calculate scroll speed based on timed speech time
        calculateScrollSpeed()
        
        // Save the new timed speech time to UserDefaults
        UserDefaults.standard.set(timedSpeechTime, forKey: "TimedSpeechTime")
    }
    
    func calculateScrollSpeed() {
        // Calculate the scroll speed to make the text view reach the end in the designated time
        
        // Calculate the total content height of the text view
        let totalContentHeight = textView.contentSize.height
        
        // Calculate the required scroll speed to finish scrolling in the designated time
        scrollSpeed = totalContentHeight / CGFloat(timedSpeechTime)
    }
    
    func didSelectFont(_ selectedFont: UIFont) {
        // Convert the UIFont to Data using NSKeyedArchiver
        let fontData = NSKeyedArchiver.archivedData(withRootObject: selectedFont)
        textView.font = selectedFont
        UserDefaults.standard.set(fontData, forKey: "SelectedFont")
        syncExternalTextView()
    }
    
    func didSelectTextAlignment(_ textAlignment: NSTextAlignment) {
        textView.textAlignment = textAlignment
        syncExternalTextView()
    }
    
    // Implement SettingsDelegate methods
    func didSelectBackgroundColor(_ color: UIColor) {
        print ("Called Background Color")
        textView.backgroundColor = color
        // Save preference
        UserDefaults.standard.set(color.hexString, forKey: "BackgroundColor")
        syncExternalTextView()
    }
    
    func didSelectFontColor(_ color: UIColor) {
        textView.textColor = color
        // Save preference
        UserDefaults.standard.set(color.hexString, forKey: "FontColor")
        syncExternalTextView()
    }
    
    func didChangeFontSize(_ fontSize: CGFloat) {
        // Check if a custom font was previously selected
        if let loadedFont = loadSelectedFont() {
            // If a custom font was previously selected, adjust its size
            textView.font = loadedFont.withSize(fontSize)
            syncExternalTextView()
        } else {
            // If no custom font was previously selected, use the system font with the new size
            textView.font = UIFont.systemFont(ofSize: fontSize)
            syncExternalTextView()
        }
        
        // Save the font size to UserDefaults
        UserDefaults.standard.set(fontSize, forKey: "FontSize")
    }
    
    func didChangeLineHeight(_ lineHeight: CGFloat) {
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
        
        // Save the line height to UserDefaults
        UserDefaults.standard.set(lineSpacing, forKey: "LineSpacing")
        // Post notification to update external display
        NotificationCenter.default.post(name: .lineHeightChanged, object: nil, userInfo: ["lineHeight": lineHeight])
    }
    
   
    
    @objc func displayPaywall() {
          let nextVC = PaywallViewController()
          nextVC.delegate = self
          present(nextVC, animated: true, completion: nil)
      }

    func checkPremiumStatus() {
            Purchases.shared.getCustomerInfo { (customerInfo, error) in
                if let customerInfo = customerInfo, error == nil {
                    if customerInfo.entitlements.all["Pro Upgrade"]?.isActive == true {
                        print("Customer has upgraded")
                        // Handle any initial setup if needed
                    } else {
                        print("Customer has NOT upgraded")
                        if UserDefaults.standard.bool(forKey: "hasLaunchedOnce") == false {
                            self.displayPaywall()
                            UserDefaults.standard.set(true, forKey: "hasLaunchedOnce")
                            UserDefaults.standard.synchronize()
                        }
                    }
                }
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
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
        
    func presentSignOutAlert() {
            let alertController = UIAlertController(title: "Signed Out", message: "You have been signed out.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
               //Do nothing
                print ("Signed out")
            }
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
   
    var captionsTextView: UITextView!
    
    @objc func handlePresentSecretUpgradeOffer() {
           DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
               guard let self = self else { return }
               let secretUpgradeVC = SecretUpgradeOfferViewController()
               secretUpgradeVC.modalPresentationStyle = .fullScreen
               self.present(secretUpgradeVC, animated: true, completion: nil)
           }
       }
    
    func setupRecordButton() {
           recordButton.backgroundColor = .darkGray
           recordButton.layer.cornerRadius = 10 // Adjust as needed
           recordButton.clipsToBounds = true // Ensure the button clips to its bounds
           recordButton.addTarget(self, action: #selector(recordButtonTapped(_:)), for: .touchUpInside)
       }
    
    func setupActivityIndicator() {
           // Initialize the container view
           let containerWidth: CGFloat = 200
           let containerHeight: CGFloat = 150
           let containerX = (view.frame.width - containerWidth) / 2
           let containerY = (view.frame.height - containerHeight) / 2
           
           containerView = UIView(frame: CGRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight))
           containerView.backgroundColor = UIColor(white: 0.0, alpha: 0.7) // Translucent grey
           containerView.layer.cornerRadius = 10
           view.addSubview(containerView)
           
           // Initialize the activity indicator
           activityIndicator = UIActivityIndicatorView(style: .large)
           activityIndicator.color = .white
           activityIndicator.hidesWhenStopped = true
           let indicatorWidth = activityIndicator.frame.width
           let indicatorHeight = activityIndicator.frame.height
           let indicatorX = (containerWidth - indicatorWidth) / 2
           let indicatorY = 20 // 20 points from the top
           
        activityIndicator.frame = CGRect(x: indicatorX, y: CGFloat(indicatorY), width: indicatorWidth, height: indicatorHeight)
           containerView.addSubview(activityIndicator)
           
           // Initialize the activity label
           let labelX: CGFloat = 10
        let labelY = indicatorY + Int(indicatorHeight) + 10
           let labelWidth = containerWidth - 20
           let labelHeight: CGFloat = 40 // Adjust height as needed
           
        activityLabel = UILabel(frame: CGRect(x: labelX, y: CGFloat(labelY), width: labelWidth, height: labelHeight))
           activityLabel.text = "Please wait... Generating captions"
           activityLabel.textColor = .white
           activityLabel.textAlignment = .center
           activityLabel.numberOfLines = 0
        activityLabel.adjustsFontSizeToFitWidth = true // Adjust the font size to fit the width
        activityLabel.minimumScaleFactor = 0.5 
           containerView.addSubview(activityLabel)
           
           // Initially hide the container view
           containerView.isHidden = true
       }
    
    
    // MARK: View Did Load
    
    var activityLabel: UILabel!
    var activityIndicator: UIActivityIndicatorView!
    var containerView: UIView!
    
    struct AdConfig: Decodable {
        let showBannerAd: Bool
        let showInterstitialAd: Bool
        let useSky: Bool?
        let AdCount: Int?
        
        enum CodingKeys: String, CodingKey {
            case showBannerAd
            case showInterstitialAd
            case useSky
            case AdCount
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Parse `showBannerAd` and `showInterstitialAd` as `String` and explicitly convert to `Bool`
            let bannerString = try? container.decode(String.self, forKey: .showBannerAd)
            self.showBannerAd = (bannerString?.lowercased() == "true")
            
            let interstitialString = try? container.decode(String.self, forKey: .showInterstitialAd)
            self.showInterstitialAd = (interstitialString?.lowercased() == "true")
            
            // Parse optional fields `useSky` and `AdCount` as usual
            self.useSky = try? container.decode(Bool.self, forKey: .useSky)
            self.AdCount = try? container.decode(Int.self, forKey: .AdCount)
        }
        
        // Default initializer to use if JSON is missing
        init(showBannerAd: Bool = true, showInterstitialAd: Bool = true, useSky: Bool? = nil, AdCount: Int? = nil) {
            self.showBannerAd = showBannerAd
            self.showInterstitialAd = showInterstitialAd
            self.useSky = useSky
            self.AdCount = AdCount
        }
    }



    private var adConfig: AdConfig?

    func showInterstitialAd() {
        if let interstitialAd = interstitialAd {
            interstitialAd.present(fromRootViewController: self)
        } else {
            print("Interstitial ad was not ready to be shown.")
        }
    }


    func fetchAdConfig() {
        guard let url = URL(string: "https://mattcowlin.com/DougHasNoFriends/config.json") else {
            print("Invalid URL. Defaulting to show ads.")
            adConfig = AdConfig()  // Uses default values for ad visibility
            updateInterstitialAdVisibility()
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let data = data, error == nil {
                do {
                    self.adConfig = try JSONDecoder().decode(AdConfig.self, from: data)
                    print("Successfully fetched ad config:", self.adConfig!)
                } catch {
                    print("Failed to parse ad config; using default values.")
                    self.adConfig = AdConfig()
                }
            } else {
                print("Failed to fetch ad config:", error?.localizedDescription ?? "No error description")
                self.adConfig = AdConfig() // Default to showing ads
            }

            DispatchQueue.main.async {
            //    self.updateBannerAdVisibility()
                self.updateInterstitialAdVisibility()
            }
        }.resume()
    }

    
    func updateInterstitialAdVisibility() {
        guard let adConfig = adConfig else {
            loadInterstitialAd()
            return
        }

        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            guard let self = self else { return }
            
            let isUpgraded = customerInfo?.entitlements["Pro Upgrade"]?.isActive == true
            
            if !isUpgraded && adConfig.showInterstitialAd {
                self.loadInterstitialAd()
            }
        }
    }
    
    func loadInterstitialAd() {
        let request = GADRequest()
        //REAL KEY ca-app-pub-3785918208569837/8847847017
        
//            TEST KEY ca-app-pub-3940256099942544/4411468910
        
        GADInterstitialAd.load(withAdUnitID: "ca-app-pub-3785918208569837/8847847017", request: request) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error)")
                return
            }
            self?.interstitialAd = ad
            self?.interstitialAd?.fullScreenContentDelegate = self
            self?.showInterstitialAd() // Show the ad once loaded
        }
    }

    
    
   

    
    
    override func viewDidAppear(_ animated: Bool) {
          super.viewDidAppear(animated)
          // Setup the tap gesture recognizer in viewDidAppear
          setupTapGestureRecognizer()
        // Force layout update
               view.setNeedsLayout()
               view.layoutIfNeeded()
               // Enable user interaction after layout updates
               view.isUserInteractionEnabled = true
  
      }
    
 
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchAdConfig()
        // Disable animations
        
        // Add observer to detect scroll changes
        textView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
   //     let isVDLExternalDisplayEnabled = UserDefaults.standard.bool(forKey: "ExternalDisplayEnabled")
    //           didToggleExternalDisplay(isEnabled: isVDLExternalDisplayEnabled)
        // Register for screen connect/disconnect notifications
        NotificationCenter.default.addObserver(self, selector: #selector(screenDidConnect(_:)), name: UIScreen.didConnectNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(screenDidDisconnect(_:)), name: UIScreen.didDisconnectNotification, object: nil)
             
        let isEnabled = UserDefaults.standard.bool(forKey: "ExternalDisplayEnabled")
               if isEnabled, let screen = UIScreen.screens.last, screen != UIScreen.main {
                   setupExternalScreen(screen: screen, shouldRecurse: true)
                   print("External Display Toggled ON")
               }
        // Log available screens
        let screens = UIScreen.screens
        for screen in screens {
            print("Screen: \(screen)")}
        UIView.setAnimationsEnabled(false)
        // Load the Tap to Scroll state from UserDefaults
        isTapToScrollEnabled = UserDefaults.standard.bool(forKey: "isTapToScrollEnabled")
        applyTapToScrollState(isEnabled: isTapToScrollEnabled)
        setupRecordButton()
        setupActivityIndicator()
        loadMarginsFromDefaults()
        updatePlayButton()
        isScrolling = false
        requestSpeechAuthorization()
        setupCaptionsTextView()
        navigationController?.isNavigationBarHidden = false
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.backgroundColor = .black
        trackAppOpens()
        textView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(marginsUpdated(_:)), name: NSNotification.Name("MarginsUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePresentSecretUpgradeOffer), name: NSNotification.Name("PresentSecretUpgradeOffer"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        checkPremiumStatus()
        let editAction = UIAction(title: "Edit Script", image: UIImage(systemName: "pencil")) { [weak self] _ in
            self?.presentEditScriptViewController()
        }
        
        let newScriptAction = UIAction(title: "New Script", image: UIImage(systemName: "plus")) { [weak self] _ in
            self?.presentEditScriptViewController(isNewScript: true)
        }
        
        let importAction = UIAction(title: "Import Script", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
            self?.importScript()
        }
        
        let menu = UIMenu(title: "", children: [editAction, newScriptAction, importAction])
        editButton.menu = menu
        editButton.showsMenuAsPrimaryAction = true
        
    //    textView.addObserver(self, forKeyPath: "contentOffset", options: [.new], context: nil)
        
        let verticalAction = UIAction(title: "Mirror Vertically", image: UIImage(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")) { [weak self] _ in
            self?.toggleMirrorTextViewVertically(UIButton())
        }
        
        let horizontalAction = UIAction(title: "Mirror Horizontally", image: UIImage(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")) { [weak self] _ in
            self?.toggleMirrorTextViewHorizontally(UIButton())
        }
        
        let mirrorMenu = UIMenu(title: "", children: [verticalAction, horizontalAction])
        mirrorButton.menu = mirrorMenu
        mirrorButton.showsMenuAsPrimaryAction = true
        
        let cueModeEnabled = UserDefaults.standard.bool(forKey: "cueEnabled")
        let reverseModeEnabled = UserDefaults.standard.bool(forKey: "ReverseModeEnabled")
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleTimerTimeDidChange(_:)), name: NSNotification.Name("StartTimerTimeDidChange"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTimerSettingsChange(_:)), name: NSNotification.Name("StartTimerSettingsDidChange"), object: nil)
        
        let isStartTimerEnabled = UserDefaults.standard.bool(forKey: "StartTimerModeEnabled")
        let startTimerTime = UserDefaults.standard.double(forKey: "StartTimerTime")
        
        if isStartTimerEnabled {
            startTimerEnabled = true
            if let savedTime = UserDefaults.standard.object(forKey: "StartTimerTime") as? Double {
                self.startTimerTime = savedTime
                print("Start timer is enabled")
                print("Start timer time: \(startTimerTime)")
            } else {
                print("Start timer time not found in UserDefaults")
            }
        } else {
            startTimerEnabled = false
            print("Start timer is disabled")
        }
        
        if cueModeEnabled {
            displayCue()
            controlsContainer.isHidden = true
        } else {
            removeCue()
        }
        
        if reverseModeEnabled {
            isReverseModeEnabled = true
        } else {
            isReverseModeEnabled = false
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(timedSpeechSwitchStateChanged(_:)), name: TimedSpeechCell.timedSpeechSwitchStateChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleTimedSpeechTimeDidChange(_:)), name: NSNotification.Name("TimedSpeechTimeDidChange"), object: nil)
        
        isTimedSpeechEnabled = UserDefaults.standard.bool(forKey: "TimedSpeechSwitchState")
        if UserDefaults.standard.object(forKey: "TimedSpeechTime") == nil {
            UserDefaults.standard.set(30.0, forKey: "TimedSpeechTime")
        }
        timedSpeechTime = UserDefaults.standard.double(forKey: "TimedSpeechTime")
        
        if isTimedSpeechEnabled {
            speedSlider.isEnabled = false
            textView.isUserInteractionEnabled = false
            showCountdownView()
            showElapsedTimeView()
        }
        loadPreferences()
        textView.isEditable = false
        
        

       
        
        
        let screenHeight = UIScreen.main.bounds.height
        let blankSpaceHeight = screenHeight / 3.0
        let offset = CGPoint(x: 0, y: -blankSpaceHeight)
        textView.contentInset = UIEdgeInsets(top: blankSpaceHeight, left: 0, bottom: blankSpaceHeight, right: 0)
        textView.contentOffset = offset
        
        if isReverseModeEnabled {
            if isTimedSpeechEnabled {
                resetTextViewPosition()
                hideCountdownView()
                hideElapsedTimeView()
                elapsedTimeTimer?.invalidate()
                elapsedTimeTimer = nil
                elapsedNewTime = 0
                showCountdownView()
                showElapsedTimeView()
                textView.isUserInteractionEnabled = false
            }
        }
        updateEyeFocusMode()
        printScripts()
        if let script = currentScript {
            displayScript(script)
        }
        
        
        isPaginationEnabled = UserDefaults.standard.bool(forKey: "isPaginationEnabled")
        
        // Apply the pagination state
        if isPaginationEnabled {
            let topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin"))
            let bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
            let leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
            let rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))
            
            let adjustedBottomMargin = bottomMargin < 220 ? 220 : bottomMargin
            adjustTextViewHeightAndPosition(for: paginationTextView, top: topMargin, bottom: adjustedBottomMargin)
            paginationTextView.textContainerInset = UIEdgeInsets(top: 0, left: leftMargin, bottom: 0, right: rightMargin)
            
            paginateText()
            updatePlayButton()
        } else {
            loadMarginsFromDefaults()
            updatePlayButton()
        }
        
        // Apply the pagination state after the view has loaded
           DispatchQueue.main.async {
               self.applyPaginationState()
           }
        
        // Re-enable animations after a delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              UIView.setAnimationsEnabled(true)
          }
        
        // Ensure textView is user interactable
        textView.isUserInteractionEnabled = true
        
        // Bring the view to the front to ensure it receives touch events
        self.view.bringSubviewToFront(view)
        // Disable user interaction initially
        view.isUserInteractionEnabled = false
        initializeHighlightLineSettings()
    }
    
    private func initializeHighlightLineSettings() {
        // Set initial font color to white
        textView.textColor = .white
        print("Initial font color set to white")

        // Check and set user-specified font color
        if let fontColorHex = UserDefaults.standard.string(forKey: "FontColor"),
           let fontColor = UIColor(hexString: fontColorHex) {
            textView.textColor = fontColor
            print("User-specified font color set: \(fontColor)")
        }

        // Save the initial font color to UserDefaults for later use
        if let initialFontColor = textView.textColor {
            let initialFontColorHex = initialFontColor.toHexString()
            print("Saving initial font color hex: \(initialFontColorHex)")  // Debug statement
            UserDefaults.standard.set(initialFontColorHex, forKey: "InitialFontColor")
            UserDefaults.standard.synchronize() // Ensure it is saved immediately
            print("Initial font color saved: \(initialFontColorHex)")
        } else {
            print("Failed to get initial font color from textView")
        }

        // Ensure the highlight line number is set
        let highlightLineNumber = UserDefaults.standard.highlightLineNumber
        if highlightLineNumber == 0 {
            UserDefaults.standard.highlightLineNumber = 4 // Default to the fourth line
            print("Highlight line number set to default: 4")
        } else {
            print("Highlight line number retrieved from defaults: \(highlightLineNumber)")
        }

        // Ensure the highlight line color is set
        let highlightLineColor = UserDefaults.standard.highlightLineColor
        print("Highlight line color set to: \(highlightLineColor)")

        // Apply initial highlight if enabled
        if UserDefaults.standard.highlightLineEnabled {
            highlightSpecifiedLine()
            print("Highlight line applied")
        }
    }

    
    private func setupTapGestureRecognizer() {
        // Remove any existing gesture recognizers to avoid duplicates
        view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
        
        // Add tap gesture recognizer to the view
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1 // Ensure it recognizes single taps
        tapGestureRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGestureRecognizer)
        textView.addGestureRecognizer(tapGestureRecognizer)
        print("Gesture recognizer added")

        // Ensure no other gesture recognizers interfere
        for recognizer in view.gestureRecognizers ?? [] {
            if recognizer != tapGestureRecognizer {
                tapGestureRecognizer.require(toFail: recognizer)
            }
        }

        // Bring the view to the front to ensure it receives touch events
        self.view.bringSubviewToFront(view)
        print("View brought to front")
    }

    
    private var previousVisibleLines: [String] = []

    func linesHaveChanged(previousLines: [String], currentLines: [String]) -> Bool {
            // Compare the previous and current lines
            guard previousLines.count == currentLines.count else { return true }
            
            for (previousLine, currentLine) in zip(previousLines, currentLines) {
                if previousLine != currentLine {
                    return true
                }
            }
            
            return false
        }
     
    func printVisibleLines(lines: [String]) {
           for (index, line) in lines.enumerated() {
               print("Line \(index + 1): \(line)")
           }
       }
    
    private func applyPaginationState() {
        isPaginationEnabled = UserDefaults.standard.bool(forKey: "isPaginationEnabled")
        
        // Apply the pagination state
        if isPaginationEnabled {
            let topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin"))
            let bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
            let leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
            let rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))
            
            let adjustedBottomMargin = bottomMargin < 220 ? 220 : bottomMargin
            adjustTextViewHeightAndPosition(for: textView, top: topMargin, bottom: adjustedBottomMargin)
            textView.textContainerInset = UIEdgeInsets(top: 0, left: leftMargin, bottom: 0, right: rightMargin)
            
            paginateText()
        } else {
            loadMarginsFromDefaults()
        }
        updatePlayButton()
    }

    func setupCaptionsTextView() {
        captionsTextView = UITextView()
        captionsTextView.translatesAutoresizingMaskIntoConstraints = false
        captionsTextView.isEditable = false
        captionsTextView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        captionsTextView.textColor = .white
        captionsTextView.font = UIFont.systemFont(ofSize: 18)
        captionsTextView.textAlignment = .center
        captionsTextView.isHidden = true // Initially hidden
        
        view.addSubview(captionsTextView)
        
        NSLayoutConstraint.activate([
            captionsTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captionsTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            captionsTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60), // Adjust this value to be above the controls
            captionsTextView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.33)
        ])
    }
    
    func requestSpeechAuthorization() {
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    switch authStatus {
                    case .authorized:
                        print("Speech recognition authorized")
                    case .denied, .restricted, .notDetermined:
                        self.showSpeechRecognitionSettingsAlert()
                    @unknown default:
                        fatalError("Unknown speech recognition authorization status")
                    }
                }
            }
        }

    func showSpeechRecognitionSettingsAlert() {
            let alertController = UIAlertController(
                title: "Speech Recognition Not Authorized",
                message: "Please enable speech recognition in Settings.",
                preferredStyle: .alert
            )

            let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                }
            }
            alertController.addAction(settingsAction)

            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)

            present(alertController, animated: true, completion: nil)
        }
    
    private func displayScript(_ script: Script) {
        textView.text = script.content
    }
    
    @IBAction func goBack(_ sender: UIButton) {
        print("Attempting to pop view controller")
        if let navigationController = self.navigationController {
            print("Navigation controller stack before pop: \(navigationController.viewControllers)")
            navigationController.popViewController(animated: true)
            print("Navigation controller stack after pop: \(navigationController.viewControllers)")
        } else {
            print("No navigation controller found")
        }
    }
    
    deinit {
        print("Deinit called")
        NotificationCenter.default.removeObserver(self)
        print("Removed all observers")

        if textView != nil {
            textView.removeObserver(self, forKeyPath: "contentOffset")
            print("Removed contentOffset observer")
        }

        scrollTimer?.invalidate()
        countdownTimer?.invalidate()
        elapsedTimeTimer?.invalidate()
        IntroCountdownTimer?.invalidate()
        
        print("ViewController deinitialized")
    }




    private func displayScript(_ script: Script?) {
         guard let script = script else { return }
         textView.text = script.content
     }

    private func printScripts() {
        if sessionStore.isSignedIn {
            // Load scripts from Firebase Firestore
            FirebaseManager.shared.loadScripts { scripts, error in
                if let error = error {
                    print("Error loading scripts: \(error)")
                    return
                }
                
                if let scripts = scripts {
                    print("Scripts from Firebase:")
                    for script in scripts {
                        print("Title: \(script.title), Content: \(script.content)")
                    }
                }
            }
        } else {
            // Load scripts from UserDefaults
            let scripts = UserDefaults.standard.loadScripts()
            print("Scripts from UserDefaults:")
            for script in scripts {
                print("Title: \(script.title), Content: \(script.content)")
            }
        }
    }
 
    func trackAppOpens() {
          let defaults = UserDefaults.standard
          
          // Get the current count of app opens
          var appOpenCount = defaults.integer(forKey: "appOpenCount")
          
          // Increment the app open count
          appOpenCount += 1
          
          // Save the updated app open count back to UserDefaults
          defaults.set(appOpenCount, forKey: "appOpenCount")
          
          // Check if the user has already rated the app
          let hasRated = defaults.bool(forKey: "hasRated")
          
          // Check if the app has been opened 6 times and the user has not already rated the app
          if appOpenCount >= 6 && !hasRated {
              // Show alert asking if they are enjoying the app
              showEnjoyingAppAlert()
              
              // Reset the app open count to 0
              defaults.set(0, forKey: "appOpenCount")
          }
      }
      
    func showEnjoyingAppAlert() {
        let alert = UIAlertController(title: "Are you enjoying using this app?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
            // User is enjoying the app, show the rating dialog
            SKStoreReviewController.requestReview()
            
            // Set the flag indicating that the user has rated the app
            UserDefaults.standard.set(true, forKey: "hasRated")
        }))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { _ in
            // User is not enjoying the app, do nothing
            // The alert will be shown again after 6 more opens
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func startCountdownIntro() {
        // Create a background view
        NotificationCenter.default.post(name: .startScrolling, object: nil)
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        backgroundView.layer.cornerRadius = 20 // Adjust the corner radius as needed
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        // Add constraints to position and size the background view
        NSLayoutConstraint.activate([
            backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            backgroundView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 7/8),
            backgroundView.heightAnchor.constraint(equalToConstant: 200) // Adjust height as needed
        ])
        
        // Create and add the countdown label to the background view
        countdownTimerLabel = UILabel()
        countdownTimerLabel.font = UIFont(name: "Impact", size: 100)
        countdownTimerLabel.textColor = .white
        countdownTimerLabel.textAlignment = .center
        countdownTimerLabel.text = formattedTime(startTimerTime)
        countdownTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(countdownTimerLabel)
        
        // Add constraints to center the label within the background view
        NSLayoutConstraint.activate([
            countdownTimerLabel.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            countdownTimerLabel.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            countdownTimerLabel.widthAnchor.constraint(equalTo: backgroundView.widthAnchor),
            countdownTimerLabel.heightAnchor.constraint(equalTo: backgroundView.heightAnchor)
        ])
        
        // Bring the background view to the back of the subviews
        view.bringSubviewToFront(backgroundView)
     
        // Start the countdown timer
        IntroCountdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }
        // Function to update the countdown label
    @objc func updateCountdown() {
            // Decrement the countdown time
            startTimerTime -= 1
            print ("Start Timer Time = ", startTimerTime)
            // Update the countdown label text
            countdownTimerLabel.text = formattedTime(startTimerTime)
            
            // Check if countdown reached zero
            if startTimerTime <= 0 {
                // Invalidate the timer
                IntroCountdownTimer?.invalidate()
                
                // Remove the countdown view from the superview
                countdownTimerLabel.removeFromSuperview()
                backgroundView.removeFromSuperview()
                
                // Invoke the desired function
                countdownFinished()
            }
        }
    
    // Implement the handler method
    @objc func handleTimerTimeDidChange(_ notification: Notification) {
        // Extract the new time from userInfo dictionary
        if let userInfo = notification.userInfo,
           let newTime = userInfo["NewTime"] as? Int {
            // Do something with the new time
            startTimerTime = Double(newTime)
            print("New time:", newTime)
        }
    }
        
    // Function to handle countdown finished
    func countdownFinished() {
            // Perform actions when countdown finishes
            print("Countdown finished!")
            playFromCountdown ()
            startTimerTime = UserDefaults.standard.double(forKey: "StartTimerTime")
            playButton.isEnabled = true
            
          
        }
        
    // Function to format time in MM:SS format
    func formattedTime(_ time: Double) -> String {
        let seconds = Int(time)
        return String(format: "%02d", seconds)
    }
    
    func resetTextViewPosition() {
        
        if !isReverseModeEnabled {
            let screenHeight = UIScreen.main.bounds.height
            let blankSpaceHeight = screenHeight / 3.0
            let offset = CGPoint(x: 0, y: -blankSpaceHeight)
            textView.contentOffset = offset
        } else {
            let screenHeight = UIScreen.main.bounds.height
            let textViewHeight = textView.bounds.height
            let blankSpaceHeight = screenHeight / 3.0

            // Set the content inset
            textView.contentInset = UIEdgeInsets(top: blankSpaceHeight, left: 0, bottom: blankSpaceHeight, right: 0)

            // Set the content offset to start at the bottom
            textView.contentOffset = CGPoint(x: 0, y: textView.contentSize.height - (textView.bounds.size.height - textView.contentInset.bottom))
        }
    }

    // Method to handle the notification
    @objc func handleTimerSettingsChange(_ notification: Notification) {
        // Extract information from the notification userInfo dictionary
        if let userInfo = notification.userInfo,
            let isEnabled = userInfo["StartTimerModeEnabled"] as? Bool,
            let time = userInfo["StartTimerTime"] as? Double {
                // Use the received information as needed
                if isEnabled {
                    // Timer is enabled
                    startTimerEnabled = true
                    self.startTimerTime = time // Use the time from notification
                    print("Start timer is enabled")
                    print("Start timer time: \(time)")
                } else {
                    // Timer is disabled
                    startTimerEnabled = false
                    print("Start timer is disabled")
                }
        }
        NotificationCenter.default.post(name: .timerModeToggled, object: nil, userInfo: ["isEnabled": startTimerEnabled])
    }

    func updateSpeedSlider(isTimedSpeechEnabled: Bool) {
        // Enable or disable the speedSlider based on the isTimedSpeechEnabled flag
        speedSlider.isEnabled = !isTimedSpeechEnabled
    }
    
    @objc func eyeFocusModeChanged(_ notification: Notification) {
        print ("Change to Eye Focus Mode Detected")
           updateEyeFocusMode()
       }
    
    func updateEyeFocusMode() {
        if eyeFocusEnabled {
            // Store previous state
            previousTextViewState = (frame: textView.frame, contentOffset: textView.contentOffset)
            
            let screenHeight = UIScreen.main.bounds.height
            let textViewHeight = screenHeight / 3.0 // One third of the screen height
            let textViewFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: textViewHeight)
            
            // Update the frame of the textView
            textView.frame = textViewFrame
            
            print("textView frame: \(textView.frame)")
            
            // Reset content inset if necessary
            textView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            
            // Ensure the start of the text is displayed at the top of the textView
            textView.scrollRangeToVisible(NSMakeRange(0, 1))
            
            print("textView contentInset: \(textView.contentInset)")
            print("textView contentOffset: \(textView.contentOffset)")
        } else {
            // Eye-focus mode is disabled
            guard let previousState = previousTextViewState else {
                // If previous state is not available, reset the textView position
                resetTextViewPosition()
                return
            }
            
            // Restore previous state
            textView.frame = previousState.frame
            textView.contentOffset = previousState.contentOffset
        }
    }

    func didToggleReverseMode(_isEnabled isEnabled: Bool) {
        if isEnabled {
          isReverseModeEnabled = true
            if isTimedSpeechEnabled {
                resetTextViewPosition()
                hideCountdownView()
                hideElapsedTimeView()
                elapsedTimeTimer?.invalidate()
                elapsedTimeTimer = nil
                elapsedNewTime = 0
                showCountdownView()
                showElapsedTimeView()
                textView.isUserInteractionEnabled = false
            }
            print ("Reverse Mode Enabled")
        } else {
          isReverseModeEnabled = false
            print ("Reverse Mode Disabled")
            if isTimedSpeechEnabled {
                resetTextViewPosition()
                elapsedTimeTimer?.invalidate()
                elapsedTimeTimer = nil
                elapsedNewTime = 0
                hideCountdownView()
                hideElapsedTimeView()
                showCountdownView()
                showElapsedTimeView()
                textView.isUserInteractionEnabled = false
            }
        }
    }
    
    func didToggleCueMode(isEnabled: Bool) {
        print ("Cue mode activated in ViewController")
        // Act upon the status of the cue mode (isEnabled)
        if isEnabled {
            print ("Cue Enabled")
            // Cue mode is enabled
            displayCue()
            controlsContainer.isHidden = true
            // Perform actions specific to cue mode being enabled
        } else {
            // Cue mode not is disabled
            print ("Cue Not Enabled")
            removeCue()
            // Perform actions specific to cue mode being disabled
        }
    }
    
    var previousTextViewState: (frame: CGRect, contentOffset: CGPoint)?

    func didToggleEyeFocusMode(_ isEnabled: Bool) {
        if isEnabled {
            // Store previous state
            previousTextViewState = (frame: textView.frame, contentOffset: textView.contentOffset)
            
            let screenHeight = UIScreen.main.bounds.height
            let textViewHeight = screenHeight / 3.0 // One third of the screen height
            let textViewFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: textViewHeight)
            
            // Update the frame of the textView
            textView.frame = textViewFrame
            
            print("textView frame: \(textView.frame)")
            
            // Reset content inset if necessary
            textView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            
            // Ensure the start of the text is displayed at the top of the textView
            textView.scrollRangeToVisible(NSMakeRange(0, 1))
            
            print("textView contentInset: \(textView.contentInset)")
            print("textView contentOffset: \(textView.contentOffset)")
        } else {
            // Eye-focus mode is disabled
            guard let previousState = previousTextViewState else {
                // If previous state is not available, reset the textView position
                resetTextViewPosition()
                return
            }
            
            // Restore previous state
            textView.frame = previousState.frame
            textView.contentOffset = previousState.contentOffset
        }
    }

    func loadPreferences() {
        
        if let backgroundColorHex = UserDefaults.standard.string(forKey: "BackgroundColor") {
                if let backgroundColor = UIColor(hexString: backgroundColorHex) {
                    textView.backgroundColor = backgroundColor
                }
            }
        
           
           if let fontColorHex = UserDefaults.standard.string(forKey: "FontColor") {
               if let fontColor = UIColor(hexString: fontColorHex) {
                   textView.textColor = fontColor
               }
           }
           
           if let fontSize = UserDefaults.standard.object(forKey: "FontSize") as? CGFloat {
               textView.font = UIFont.systemFont(ofSize: fontSize)
           }
        
            if let savedLineHeight = UserDefaults.standard.value(forKey: "LineSpacing") as? CGFloat {
                // Set line spacing for textView
                      setLineSpacing(savedLineHeight)
                print ("Saved Line Spacing =", savedLineHeight)
                
            } else {
                setLineSpacing(-11.0)
            }
        loadSelectedFont()
        // Call the method and assign the result to a variable
        if let loadedFont = loadSelectedFont() {
            // Do something with the loaded font, such as setting it to a label's font
            textView.font = loadedFont
        } else {
            if let fontSize = UserDefaults.standard.object(forKey: "FontSize") as? CGFloat{
                // Handle the case where the font couldn't be loaded, perhaps by using a default font
                textView.font = UIFont.systemFont(ofSize: fontSize)}
        }
        
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
}
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        
        // Get the location of the tap
        let location = gesture.location(in: view)
        print("Tap location: \(location)")

        // Calculate the height of the navigation bar area
        let navigationBarHeight = navigationController?.navigationBar.frame.height ?? 44.0 // Default height is 44 if navigation controller is nil
        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let totalBarHeight = navigationBarHeight + statusBarHeight
        print("Navigation bar height: \(navigationBarHeight)")
        print("Status bar height: \(statusBarHeight)")
        print("Total bar height: \(totalBarHeight)")

        // If the tap occurs in the area where the navigation bar would be, show the navigation bar
        if location.y < totalBarHeight {
            print("Tap is in the navigation bar area")
            navigationController?.isNavigationBarHidden = false
            return
        }

        // Hit test to find the view at the tap location
        if let hitView = view.hitTest(location, with: nil) {
            print("Hit view: \(hitView)")

            // Toggle visibility of controlsContainer if the imageView was tapped
            if hitView == cueImageView {
                controlsContainer.isHidden.toggle()
                return
            }

            // Check if the tap is on the textView
            if hitView == textView {
                print("Tap is on the textView")
                if isTapToScrollEnabled {
                    playButtonTapped(playButton)}
                else {
                    print ("Tapped to scroll but it's not enabled")
                }
                return
            }
        } else {
            print("No hit view found")
        }
    }

    func loadSelectedFont() -> UIFont? {
        // Retrieve the font data from UserDefaults
        if let fontData = UserDefaults.standard.data(forKey: "SelectedFont") {
            // Unarchive the font data to get the UIFont object
            if let selectedFont = NSKeyedUnarchiver.unarchiveObject(with: fontData) as? UIFont {
                
                textView.font = selectedFont
                print ("Selected font = ", selectedFont)
                return selectedFont
            }
        }
        return nil
    }
    
    func setLineSpacing(_ lineSpacing: CGFloat) {
        // Ensure textView.font is not nil
        guard textView.font != nil else {
            return
        }

        // Create a mutable attributed string with the existing text
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())

        // Create a paragraph style with the specified line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        // Apply the paragraph style to the entire text range
        mutableAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableAttributedString.length))

        // Update the attributed text of the textView
        textView.attributedText = mutableAttributedString
    }
    
    func adjustScrollSpeed(by amount: Float) {
        // Update the slider value
        let newValue = speedSlider.value + amount
        // Ensure the new value is within the slider's bounds
        speedSlider.value = max(speedSlider.minimumValue, min(speedSlider.maximumValue, newValue))
        // Call the slider's IBAction to update the scroll speed
        speedSliderChanged(speedSlider)
    }
    
    @IBAction func speedSliderChanged(_ sender: UISlider) {
        // Update scroll speed based on slider value
        scrollSpeed = Double(sender.value)
        
        // If scrolling is currently active, restart scrolling with the new speed
        if scrollTimer != nil {
            pauseScrolling()
            startScrolling()
        }
    }
    
    @IBAction func hideNavigationBarButtonTapped(_ sender: UIButton) {
        // Toggle the visibility of the navigation bar
        navigationController?.isNavigationBarHidden.toggle()
    }
    
    @IBAction func toggleMirrorTextViewVertically(_ sender: UIButton) {
        isPremiumUser { [weak self] isPremium in
            guard let self = self else { return }
            if !isPremium {
                self.showUpgradeAlert()
                return
            }

            // Check if the text view is currently mirrored vertically
            let isMirroredVertically = self.textView.transform.d == -1

            // Toggle the vertical mirroring state
            if isMirroredVertically {
                // If mirrored vertically, reset to normal
                self.textView.transform = .identity
            } else {
                // If not mirrored vertically, mirror vertically
                self.textView.transform = CGAffineTransform(scaleX: 1, y: -1)
            }

            // Save the vertical mirrored state to UserDefaults
            UserDefaults.standard.set(!isMirroredVertically, forKey: "TextViewMirroredVertically")

            // Sync the external text view
            self.syncExternalTextView()
        }
    }

    @IBAction func toggleMirrorTextViewHorizontally(_ sender: UIButton) {
        isPremiumUser { [weak self] isPremium in
            guard let self = self else { return }
            if !isPremium {
                self.showUpgradeAlert()
                return
            }

            // Check if the text view is currently mirrored
            let isMirrored = self.textView.transform.a == -1

            // Toggle the mirroring state
            if isMirrored {
                // If mirrored, reset to normal
                self.textView.transform = .identity
                // Reset text alignment to original
                self.textView.textAlignment = .left // Assuming the default alignment is left
            } else {
                // If not mirrored, mirror horizontally
                self.textView.transform = CGAffineTransform(scaleX: -1, y: 1)
                // Adjust text alignment for readability
                switch self.textView.textAlignment {
                case .left:
                    self.textView.textAlignment = .right
                case .right:
                    self.textView.textAlignment = .left
                default:
                    // No need to change alignment for center text
                    break
                }
            }

            // Save the mirrored state to UserDefaults
            UserDefaults.standard.set(!isMirrored, forKey: "TextViewMirrored")

            // Sync the external text view
            self.syncExternalTextView()
        }
    }
    
    func calculateScrollSpeedForTimedSpeech() {
        // Calculate the total content height of the text view including the blank space
        let screenHeight = UIScreen.main.bounds.height
        let blankSpaceHeight = (screenHeight / 3.0)*4
        
        let totalContentHeight = textView.contentSize.height + blankSpaceHeight
        print("Total Content Height:", totalContentHeight)
        
        // Calculate the scroll speed to make the entire content height scroll to the bottom within the designated time
        scrollSpeed = (Double(totalContentHeight) / timedSpeechTime) / 2 // Divide by 2 to halve the scroll speed
        print("Timed Speech Time:", timedSpeechTime)
        print("Scroll Speed:", scrollSpeed)
    }

    @objc func handleTimedSpeechTimeDidChange(_ notification: Notification) {
        if let newTime = notification.userInfo?["NewTime"] as? Double {
            // Handle the new time
            print("New timed speech time: \(newTime)")
            updateTimedSpeechTime(Int(newTime))
            resetTextViewPosition()
            // You can update your UI or perform any other actions here
        }
    }
    
    func updateTimedSpeechTime(_ newTime: Int) {
        // Clear existing timer and timer view
        clearTimerAndTimerView()
        
        // Reset script to the top of the screen
        resetScriptToTop()
        
        // Set up a new timer view with the new time
        setupTimerView(newTime)
        
        // Ensure that the script is paused and ready to play with the new time
        isPaused = true
        pausedTime = nil
        hasJustBeenReset = true
    }

    func clearTimerAndTimerView() {
        // Invalidate existing scroll timer
        scrollTimer?.invalidate()
        scrollTimer = nil
        
        // Invalidate existing countdown timer
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
        
        // Remove countdown view
        hideElapsedTimeView()
        hideCountdownView()
        isPaused = true
        isScrolling = false
        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }

    func resetScriptToTop() {
        // Reset script to the top of the screen
        textView.setContentOffset(.zero, animated: false)
    }

    func setupTimerView(_ newTime: Int) {
        // Set up a new timer view with the new time
        timedSpeechTime = TimeInterval(newTime)
        showCountdownView()
        showElapsedTimeView()
    }

    func calculateScrollSpeedForSlider() {
        // Get the scroll speed from the slider value
        scrollSpeed = Double(speedSlider.value)
    }
    
    @objc func timedSpeechSwitchStateChanged(_ notification: Notification) {
        if let isOn = notification.object as? Bool {
            // Handle the switch state change
            print("Timed speech switch state changed: \(isOn ? "On" : "Off")")
            
            // Update the state of the speedSlider
            updateSpeedSlider(isTimedSpeechEnabled: isOn)

            // Show or hide the countdown view based on the state of timed speech
            if isOn {
                resetTextViewPosition()
                isTimedSpeechEnabled = true
                showCountdownView()
                showElapsedTimeView()
                textView.isUserInteractionEnabled = false// Show the countdown view if timed speech is enabled and it hasn't been shown yet
            } else {
                isTimedSpeechEnabled = false
                hideCountdownView()
                hideElapsedTimeView()
                textView.isUserInteractionEnabled = true// Hide the countdown view if timed speech is disabled
            }
        }
    }
    
    var previousHighlightLine: Int?
    var previousHighlightColor: UIColor?
    
    
    @objc func scrollText() {
        
        
        guard let lastScrollTime = lastScrollTime else {
            self.lastScrollTime = Date().timeIntervalSinceReferenceDate
            return
        }
        
        // Calculate the time elapsed since the last scroll
        let currentTime = Date().timeIntervalSinceReferenceDate
        let elapsedTime = currentTime - lastScrollTime
        self.lastScrollTime = currentTime
        
     //  print("Elapsed Time on Scroll Text:", elapsedNewTime)
        
        // Calculate the distance to scroll based on the scroll speed and elapsed time
        let distanceToScroll = scrollSpeed * elapsedTime
        
     //   print("Distance to Scroll:", distanceToScroll)
        
        // Calculate the maximum content offset based on the text view's content size
        let screenHeight = UIScreen.main.bounds.height
        let blankSpaceHeight = screenHeight / 3.0
        let maxContentOffset = textView.contentSize.height - textView.bounds.size.height + blankSpaceHeight+1

        if !isReverseModeEnabled {
            // Check if the text view has reached the bottom
            if textView.contentOffset.y + textView.bounds.size.height >= textView.contentSize.height + blankSpaceHeight && countdownTime < 1 {
                // Stop scrolling if we've reached the end of the text plus 1/3 of the screen height
                if isTimedSpeechEnabled == true {
                    print("Stopped in ScrollText")
                    hideCountdownView()
                    hideElapsedTimeView()
                    playButton.setImage(UIImage(systemName: "arrow.clockwise.circle"), for: .normal)
                    isReplaying = true
                    pauseScrolling()
                    return
                }
                else {
                    // hideCountdownView()
                    playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    // isReplaying = true
                    pauseScrolling()
                }
            } else if !isTimedSpeechEnabled && textView.contentOffset.y + textView.bounds.size.height >= textView.contentSize.height + blankSpaceHeight {
                print("Stopped in ScrollText for not timed speech")
                // hideCountdownView()
                playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                // isReplaying = true
                pauseScrolling()
                
            }} else {
                // Check if the text view has reached the top
                if textView.contentOffset.y <= -blankSpaceHeight && countdownTime < 1 {
                    // Stop scrolling if we've reached the end of the text plus 1/3 of the screen height
                    if isTimedSpeechEnabled == true {
                        print("Stopped in ScrollText")
                        hideCountdownView()
                        hideElapsedTimeView()
                        playButton.setImage(UIImage(systemName: "arrow.clockwise.circle"), for: .normal)
                        isReplaying = true
                        pauseScrolling()
                        return
                    }
                    else {
                        // hideCountdownView()
                        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                        // isReplaying = true
                        pauseScrolling()
                    }
                } else if !isTimedSpeechEnabled && textView.contentOffset.y <= -blankSpaceHeight  {
                    print("Stopped in ScrollText for not timed speech")
                    // hideCountdownView()
                    playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    // isReplaying = true
                    pauseScrolling()
                }
            }

        
        // Calculate the new content offset based on the direction of scrolling
            var newContentOffset = textView.contentOffset
            if isReverseModeEnabled {
                newContentOffset.y -= 1 // Scroll upwards for reverse mode
            } else {
                newContentOffset.y += 1 // Scroll downwards for normal mode
            }
        
      
        
        // Limit the new content offset to the maximum content offset
        newContentOffset.y = min(newContentOffset.y, maxContentOffset)
        
       // print("New Content Offset After Calculation:", newContentOffset)
        
        // Set new content offset
        textView.setContentOffset(newContentOffset, animated: false)
        if UserDefaults.standard.highlightLineEnabled {
               highlightSpecifiedLine()
          }
    }
    
    func highlightSpecifiedLine() {
        // Retrieve highlight line number and color directly from UserDefaults using the new extensions
        let highlightLineNumber = UserDefaults.standard.highlightLineNumber
        let highlightLineColor = UserDefaults.standard.highlightLineColor
        
        // Ensure the initial font color is set and available
        guard let initialFontColorHex = UserDefaults.standard.string(forKey: "InitialFontColor"),
              let initialFontColor = UIColor(hexString: initialFontColorHex) else {
            print("Initial font color not found.")
            return
        }

        // Debug print statements
        print("Highlight Line Number: \(highlightLineNumber)")
        print("Highlight Line Color: \(highlightLineColor)")
        
        // Calculate visible range of the text view
        let visibleRect = textView.bounds
        let visibleGlyphRange = textView.layoutManager.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer)
        
        var currentLineNumber = 1
        let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
        
        // Enumerate through visible line fragments and apply highlight
        textView.layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { (rect, usedRect, textContainer, glyphRange, stop) in
            let characterRange = self.textView.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineText = (self.textView.text as NSString).substring(with: characterRange)
            print("Line \(currentLineNumber): \(lineText) with range \(characterRange)")
            
            if currentLineNumber == highlightLineNumber {
                attributedString.addAttribute(.foregroundColor, value: highlightLineColor, range: characterRange)
                print("Highlighting line \(currentLineNumber) with color \(highlightLineColor) in range \(characterRange)")
            } else {
                // Reapply the initial font color
                attributedString.addAttribute(.foregroundColor, value: initialFontColor, range: characterRange)
            }
            currentLineNumber += 1
        }
        
        // Apply the updated attributed string to the text view
        textView.attributedText = attributedString
        print("Updated attributed text applied to textView.")
        
        // Print out the attributed string to debug
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, stop in
            if let color = attributes[.foregroundColor] as? UIColor {
                print("Text in range \(range) has color \(color)")
            } else {
                print("Text in range \(range) has no color")
            }
        }
    }





    

    func startScrolling() {
        if isTimedSpeechEnabled {
            // Calculate scroll speed based on timed speech time
            calculateScrollSpeedForTimedSpeech()
            print ("Using Scroll Speed for Timed Speech = ", scrollSpeed)
            showCountdownView() // Show countdown view only if timed speech mode is enabled
        } else {
            // Calculate scroll speed based on slider value
            calculateScrollSpeedForSlider()
            print ("Using Scroll Speed for Timed Speech = ", scrollSpeed)
        }
        isScrolling = true
        // Start the scrolling timer
        scrollTimer = Timer.scheduledTimer(timeInterval: 1 / scrollSpeed, target: self, selector: #selector(scrollText), userInfo: nil, repeats: true)
        editButton.isEnabled = false
    }

    func pauseScrolling() {
        // Pause scrolling
        isScrolling = false
        isPaused = true
        pausedTime = Date() // Store the current time when pausing
        
        // Store the current content offset
        lastContentOffset = textView.contentOffset
        print("Paused scrolling. Content offset at pause:", lastContentOffset ?? "Unknown")
        
        // Check if the scrolling timer is currently running
        if scrollTimer != nil {
            print("Scroll timer is running before invalidation")
        }
        
        // Stop scrolling timer
        scrollTimer?.invalidate()
        scrollTimer = nil
        
        // Check if the scrolling timer has stopped after invalidation
        if scrollTimer == nil {
            print("Scroll timer has stopped after invalidation")
        }
        
        editButton.isEnabled = true
      //  pauseElapsedTimeTimer()
        // Pause countdown timer and store remaining time
        if let countdownTimer = countdownTimer {
            countdownTimer.invalidate()
            self.countdownTimer = nil
            
        }
        if let elapseTimer = elapsedTimeTimer {
            elapseTimer.invalidate()
            self.elapsedTimeTimer = nil
        }
        
        // Debug statement to print elapsed time
           print("Elapsed Time im pause:", elapsedNewTime)
       
        
        // Check if less than one second remaining in the countdown and the script has stopped moving
        if countdownTime < 1 && !isScrolling {
            print ("Countdown timer is less than one and it's not scrolling")
            // Trigger the desired action here, such as resetting the script to the top
            // and updating the play button image
          // textView.setContentOffset(.zero, animated: false)
          //  countdownTime = Int(timedSpeechTime) // Reset countdown time to the selected time
           // playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        }
    }

    func resumeScrolling() {
        // Invalidate the existing countdown timer
        print("Elapsed Time before invalidating:", elapsedNewTime)
        countdownTimer?.invalidate()
        countdownTimer = nil
      //  elapsedTimeTimer?.invalidate()
      //  elapsedTimeTimer = nil
        print("Elapsed Time after invalidating:", elapsedNewTime)
        
        // Calculate the elapsed time since pause
        guard let pausedTime = pausedTime else { return }
      
        
        // Debug statement to print elapsed time
           print("Elapsed Time on resume:", elapsedNewTime)
        
        // Start the elapsed time timer with the adjusted elapsed time
       
        
        // Restart the scrolling timer after adjusting the content offset
        startScrolling()
        
        // Restart the countdown timer with the remaining countdown time
        startCountdownTimer()
        startElapsedTimeTimer()
        print("Started elapsed time timer")
    }

    func pauseElapsedTimeTimer() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
    }

    func showCountdownView() {
        guard isTimedSpeechEnabled else {
            hideCountdownView() // Hide the countdown view if timed speech is disabled
            print("Countdown view hidden because timed speech is disabled")
            return
        }
        
        if countdownLabel == nil {
            // Create countdown view
          
            let countdownView = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 50))
            countdownView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.7)
            countdownView.layer.cornerRadius = 10
            
            // Position the countdown view in the bottom third of the screen
            let bottomThirdY = view.bounds.height * 2 / 3
            countdownView.frame.origin = CGPoint(x: (view.bounds.width - countdownView.frame.width) / 2, y: bottomThirdY)
            
            // Create countdown label
            let label = UILabel(frame: countdownView.bounds)
            label.textColor = .white
            label.textAlignment = .center
            label.font = UIFont(name: "Courier New", size: 20) // Set font to Courier New
            countdownView.addSubview(label)
            countdownLabel = label
            
            // Store reference to countdown view
            self.countdownView = countdownView
            
            view.addSubview(countdownView)
            
            // Reset countdown time to the newly selected time
            countdownTime = Int(timedSpeechTime)
            
            // Update countdown label text
            countdownLabel?.text = String(format: "%02d:%02d", countdownTime / 60, countdownTime % 60)

            
            // Make the countdown view draggable
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            countdownView.addGestureRecognizer(panGesture)
            
            print("Countdown view shown")
        }
    }

    @IBAction func playButtonTapped(_ sender: UIButton) {
        if isPaginationEnabled {
            nextPage()
            print ("Next button pressed")
        } else {
            
            if startTimerEnabled && !isScrolling {
                playButton.isEnabled = false
                startCountdownIntro()
            } else {
                let totalContentHeight = textView.contentSize.height
                let visibleContentHeight = textView.bounds.height
                let offset = textView.contentOffset.y
                
                print ("Played from No Countdown!")
                
                
                if isReplaying { // Called when TimedSpeech reaches the bottom
                    if isTimedSpeechEnabled {
                        isPaused = false
                        startScrolling()
                        isScrolling = true  // Ensure the isScrolling flag is set
                        countdownTime = Int(timedSpeechTime)
                        startElapsedTimeTimer()
                        startCountdownTimer()
                        showCountdownView()
                        showElapsedTimeView()
                        resetTextViewPosition()
                        playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                        isReplaying = false
                    } else { //Prob never called
                        startScrolling()
                        isPaused = false
                        resetTextViewPosition()
                        playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                        isReplaying = false
                    }
                }
                
                if hasJustBeenReset {
                    hasJustBeenReset = false
                    startScrolling()
                    isScrolling = true  // Ensure the isScrolling flag is set
                    startCountdownTimer()
                    startElapsedTimeTimer()
                    playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                } else {
                    if isScrolling { // If currently scrolling, pause
                        print ("Pause Pressed")
                        pauseScrolling()
                        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    } else { // If not scrolling, start or resume scrolling
                        if isTimedSpeechEnabled && isPaused { // If timed speech is enabled and it was paused
                            resumeScrolling()
                            print ("Resume on TimeSpeech Pressed")
                            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                        } else {
                            let screenHeight = UIScreen.main.bounds.height
                            let blankSpaceHeight = screenHeight / 3.0
                            
                            // Calculate the maximum content offset based on the text view's content size and the presence of blank space
                            let maxContentOffset: CGFloat
                            if !isReverseModeEnabled {
                                maxContentOffset = totalContentHeight + blankSpaceHeight
                            } else {
                                maxContentOffset = -blankSpaceHeight
                            }
                            
                            if (!isReverseModeEnabled && (offset + visibleContentHeight >= maxContentOffset )) ||
                                (isReverseModeEnabled && (offset <= -blankSpaceHeight )) {
                                // Display error message for reaching the end of the script
                                displayErrorMessage("End of your script reached. Please reposition the script to continue to scroll.")
                                print("offset:", offset)
                                print("visibleContentHeight:", visibleContentHeight)
                                print("totalContentHeight:", totalContentHeight)
                                print("blankSpaceHeight:", blankSpaceHeight)
                            } else {
                                // Start or resume scrolling
                                print("Resume on non timedSpeech Pressed")
                                startScrolling()
                                isScrolling = true  // Ensure the isScrolling flag is set
                                startCountdownTimer()
                                startElapsedTimeTimer() // Start countdown timer when play button is pressed
                                playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                            }
                            
                        }
                    }
                }
            }
        }
    }
    
    func playFromCountdown () {
       
        print ("Played from Countdown!")
        let totalContentHeight = textView.contentSize.height
        let visibleContentHeight = textView.bounds.height
        let offset = textView.contentOffset.y
        
        if isReplaying { // Called when TimedSpeech reaches the bottom
            if isTimedSpeechEnabled {
                isPaused = false
                startScrolling()
                countdownTime = Int(timedSpeechTime)
                startElapsedTimeTimer()
                startCountdownTimer()
                showCountdownView()
                showElapsedTimeView()
                resetTextViewPosition()
                playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                isReplaying = false
            } else { //Prob never called
                startScrolling()
                isPaused = false
                resetTextViewPosition()
                playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                isReplaying = false
            }
        }
        
        if hasJustBeenReset {
            hasJustBeenReset = false
            elapsedTimeTimer?.invalidate()
            hideElapsedTimeView()
            startScrolling()
            startCountdownTimer()
            startElapsedTimeTimer()
            playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        } else {
            if isScrolling { // If currently scrolling, pause
                print ("Pause Pressed")
                pauseScrolling()
                playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            } else { // If not scrolling, start or resume scrolling
                if isTimedSpeechEnabled && isPaused { // If timed speech is enabled and it was paused
                    resumeScrolling()
                    print ("Resume on TimeSpeech Pressed")
                    playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                } else {
                    let screenHeight = UIScreen.main.bounds.height
                    let blankSpaceHeight = screenHeight / 3.0

                    // Calculate the maximum content offset based on the text view's content size and the presence of blank space
                    let maxContentOffset: CGFloat
                    if !isReverseModeEnabled {
                        maxContentOffset = totalContentHeight + blankSpaceHeight
                    } else {
                        maxContentOffset = -blankSpaceHeight
                    }

                    if (!isReverseModeEnabled && (offset + visibleContentHeight >= maxContentOffset )) ||
                        (isReverseModeEnabled && (offset <= -blankSpaceHeight )) {
                        // Display error message for reaching the end of the script
                        displayErrorMessage("End of your script reached. Please reposition the script to continue to scroll.")
                        print("offset:", offset)
                        print("visibleContentHeight:", visibleContentHeight)
                        print("totalContentHeight:", totalContentHeight)
                        print("blankSpaceHeight:", blankSpaceHeight)
                    } else {
                        // Start or resume scrolling
                        print("Resume on non timedSpeech Pressed")
                        startScrolling()
                        startCountdownTimer()
                        startElapsedTimeTimer() // Start countdown timer when play button is pressed
                        playButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
                    }

                }
            }
        }
    }
    
    // Function to display an error message
    func displayErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func hideCountdownView() {
        countdownView?.removeFromSuperview()
        countdownLabel = nil
        print("Countdown view hidden")
    }
    
    // Function to display the elapsed time view
    func showElapsedTimeView() {
        // Remove any existing elapsed time view
      //  hideElapsedTimeView()
        
        // Create elapsed time view
        let elapsedTimeView = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 50))
        elapsedTimeView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.7)
        elapsedTimeView.layer.cornerRadius = 10
        
        // Position the elapsed time view in the top third of the screen
        let topThirdY = view.bounds.height / 3 - elapsedTimeView.frame.height / 2
        elapsedTimeView.frame.origin = CGPoint(x: (view.bounds.width - elapsedTimeView.frame.width) / 2, y: topThirdY)
        
        // Create elapsed time label
        let label = UILabel(frame: elapsedTimeView.bounds)
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont(name: "Courier New", size: 20) // Set font to Courier New
        if elapsedTimeLabel?.text == nil || elapsedTimeLabel?.text?.isEmpty ?? true {
                label.text = "00:00"
            }// Set initial text to "00:00"
        elapsedTimeView.addSubview(label)
        elapsedTimeLabel = label
        
        // Store reference to elapsed time view
        self.elapsedTimeView = elapsedTimeView
        // Add pan gesture recognizer to make the view draggable
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            elapsedTimeView.addGestureRecognizer(panGesture)
        view.addSubview(elapsedTimeView)
        
        // Start updating elapsed time
      //  startElapsedTimeTimer()
        
        print("Elapsed time view shown")
    }

    // Function to hide the elapsed time view
    func hideElapsedTimeView() {
        elapsedTimeTimer?.invalidate()
        elapsedTimeTimer = nil
        elapsedTimeView?.removeFromSuperview()
        elapsedTimeView = nil
       // elapsedNewTime = 0 // Reset elapsed time
        elapsedTimeLabel = nil
        print("Elapsed time view hidden")
    }

    // Function to start the elapsed time timer
    func startElapsedTimeTimer() {
        elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedNewTime += 1
            print ("elapsed Time update = ", self?.elapsedNewTime)
            // Update the UI with the updated elapsed time
            self?.updateElapsedTimeLabel()
        }
    }

    // Function to update the elapsed time label with the current elapsed time
    func updateElapsedTimeLabel() {
        guard let elapsedTimeLabel = elapsedTimeLabel else { return }
        let minutes = elapsedNewTime / 60
        let seconds = elapsedNewTime % 60
        let formattedTime = String(format: "%02d:%02d", minutes, seconds)
        DispatchQueue.main.async {
            elapsedTimeLabel.text = formattedTime
        }
    }

    func resumeElapsedTimeTimer() {
        startElapsedTimeTimer()
    }

    func startCountdownTimer() {
       
        // Restart countdown timer with remaining time
        guard countdownTime > 0 else { return }
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            let minutes = self.countdownTime / 60
            let seconds = self.countdownTime % 60
            self.countdownLabel?.text = String(format: "%02d:%02d", minutes, seconds)
            
            self.countdownTime -= 1
            if self.countdownTime < 0 {
                timer.invalidate()
                self.countdownView?.removeFromSuperview()
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
                    let currentVisibleLines = textView.visibleLines()
                    if linesHaveChanged(previousLines: previousVisibleLines, currentLines: currentVisibleLines) {
                        previousVisibleLines = currentVisibleLines
                        printVisibleLines(lines: currentVisibleLines)
                      //  highlightSpecifiedLine()
                    }
                }
        if keyPath == "contentOffset", let contentOffset = change?[.newKey] as? CGPoint {
            if !isReverseModeEnabled {
                if isTimedSpeechEnabled && contentOffset.y <= 0 && countdownTime < 0 {
                    // The text view has reached the top
                    print ("WORKED")
                    // Reset the script to the top and handle other actions
                    //   textView.setContentOffset(.zero, animated: false)
                    countdownTime = Int(timedSpeechTime) // Reset countdown time to the selected time
                    if isTimedSpeechEnabled == true {
                        print("Stopped in observed")
                        hideCountdownView()
                        elapsedNewTime = 0
                        playButton.setImage(UIImage(systemName: "arrow.clockwise.circle"), for: .normal)
                        isReplaying = true
                        pauseScrolling()
                        
                    }
                    if isScrolling { // If currently scrolling, pause
                        //      pauseScrolling()
                        if isTimedSpeechEnabled == true {
                            print("Stopped in observed 2")
                            hideCountdownView()
                            elapsedNewTime = 0
                            playButton.setImage(UIImage(systemName: "arrow.clockwise.circle"), for: .normal)
                            isReplaying = true
                            pauseScrolling()
                        }
                        //      playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    }
                }
            } else {
                if isTimedSpeechEnabled && contentOffset.y >= (textView.contentSize.height - textView.bounds.height) && countdownTime < 0 {
                    // The text view has reached the bottom
                    print ("WORKED")
                    // Reset the script to the top and handle other actions
                    //   textView.setContentOffset(.zero, animated: false)
                    countdownTime = Int(timedSpeechTime) // Reset countdown time to the selected time
                    if isTimedSpeechEnabled == true {
                        print("Stopped in observed")
                        hideCountdownView()
                        playButton.setImage(UIImage(systemName: "arrow.clockwise.circle"), for: .normal)
                        isReplaying = true
                        pauseScrolling()
                        
                    }
                    if isScrolling { // If currently scrolling, pause
                        //      pauseScrolling()
                        if isTimedSpeechEnabled == true {
                            print("Stopped in observed 2")
                            hideCountdownView()
                            playButton.setImage(UIImage(systemName: "arrow.clockwise.circle"), for: .normal)
                            isReplaying = true
                            pauseScrolling()
                        }
                        //      playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
                    }
                }}
            }
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let viewToDrag = gesture.view else { return }
        let translation = gesture.translation(in: view)
        viewToDrag.center = CGPoint(x: viewToDrag.center.x + translation.x, y: viewToDrag.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
    }

    @IBAction func settingsButtonTapped(_ sender: UIButton) {
        print("Tapped Settings Button")
        
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let settingsVC = storyboard.instantiateViewController(withIdentifier: "SettingsView") as? SettingsViewController else {
            fatalError("Unable to instantiate SettingsViewController from storyboard")
        }

        settingsVC.delegate = self
        settingsVC.currentFontSize = textView.font?.pointSize ?? 17

        // Retrieve the saved line height from UserDefaults
        if let savedLineHeight = UserDefaults.standard.value(forKey: "LineHeight") as? CGFloat {
            settingsVC.currentLineHeight = savedLineHeight
        } else {
            settingsVC.currentLineHeight = 1.0 // Default value if not saved
        }
        
        // Set the timed speech state
        settingsVC.isTimedSpeechEnabled = isTimedSpeechEnabled
        
        let navController = UINavigationController(rootViewController: settingsVC)
            navController.modalPresentationStyle = .pageSheet
            present(navController, animated: true, completion: nil)
    }

    @IBAction func editButtonTapped(_ sender: UIButton) {
      
    }

    func presentEditScriptViewController(isNewScript: Bool = false) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let editVC = storyboard.instantiateViewController(withIdentifier: "EditTextView") as? EditTextView {
                editVC.delegate = self // Set ViewController as the delegate
                if isNewScript {
                    editVC.script = nil // Pass nil to indicate a new script
                } else {
                    editVC.script = currentScript // Pass the current script to EditViewController
                }
                present(editVC, animated: true, completion: nil)
            }
        }
    
    func showScriptUpgradeAlert() {
            let alert = UIAlertController(title: "Premium Feature", message: "To import more than one script, you need to upgrade. Do you wish to upgrade now?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
                self?.displayPaywall()
            })
            present(alert, animated: true, completion: nil)
        }

    // Variable to track the number of imported scripts
    var importedScriptsCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: "ImportedScriptsCount")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ImportedScriptsCount")
        }
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

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        guard let selectedFileURL = urls.first else { return }
        
        // Validate file type
        let fileType = selectedFileURL.pathExtension.lowercased()
        if fileType != "txt" && fileType != "docx" && fileType != "pdf" {
            showAlert(title: "Unsupported File Type", message: "Please select a .txt, .docx, or .pdf file.")
            return
        }
        
        // Show confirmation alert
        let alert = UIAlertController(title: "Import Script",
                                      message: "Do wish to import this script?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
            self?.handleFileImport(url: selectedFileURL)
        })
        present(alert, animated: true, completion: nil)
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
    
    func extractTextFromDOCX(data: Data) -> String? {
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
    
    // Function to handle the app entering the foreground
    @objc func appWillEnterForeground() {
        // Check if pipView exists and is active
        if let pipView = pipView as? CustomPiPView, pipView.isPictureInPictureActive() {
            pipView.stopPictureInPicture() 
            pipView.removeFromSuperview()// Stop the custom PiP view
        }
        
        
    }
    
    func showPIPUpgradeAlert() {
            let alert = UIAlertController(title: "Premium Feature", message: "To use Picture in Picture mode more than once, you need to upgrade. Do you wish to upgrade now?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { [weak self] _ in
                self?.displayPaywall()
            })
            present(alert, animated: true, completion: nil)
        }
    
    var pipUsageCount: Int {
           get {
               return UserDefaults.standard.integer(forKey: "PiPUsageCount")
           }
           set {
               UserDefaults.standard.set(newValue, forKey: "PiPUsageCount")
           }
       }

    @IBAction func exitButtonTapped(_ sender: UIButton) {
            isPremiumUser { [weak self] isPremium in
                guard let self = self else { return }
                
                if !isPremium && self.pipUsageCount >= 1 {
                    self.showUpgradeAlert()
                    return
                }
                
                // Increment PiP usage count
                self.pipUsageCount += 1
                
                // Create and configure pipView
                let pipView = CustomPiPView()
                pipView.frame = CGRect(x: -400, y: 0, width: 400, height: 400) // Adjust frame size as needed
                pipView.scriptContent = self.textView.text // Set text content
                
                // Set up textView properties from UserDefaults
                pipView.setupTextViewPropertiesFromUserDefaults()
                pipView.selectedBackgroundAudio = UserDefaults.standard.string(forKey: "BackgroundAudioOption").flatMap { BackgroundAudioOption(rawValue: $0) } ?? .none
                // Pass scrolling speed to PiP view
                pipView.scrollingSpeed = self.scrollSpeed
                DispatchQueue.main.async {
                    // Add pipView to the view hierarchy on the main thread
                    self.view.addSubview(pipView)
                    
                    // Present the PiP window
                    if !pipView.isPictureInPictureActive() {
                        pipView.startPictureInPicture(withRefreshInterval: (0.1 / 60.0))
                    }
                }
            }
        }
    
    var cueImageView = UIImageView()
    
    func displayCue() {
        
            // Create an image view with your cue image
            cueImageView = UIImageView(image: UIImage(named: "cue.png"))
            
            // Set the frame for the image view
            let screenWidth = UIScreen.main.bounds.width
            let screenHeight = UIScreen.main.bounds.height
            let cueImageWidth: CGFloat = 100 // Adjust this value as needed
            let cueImageHeight: CGFloat = 100 // Adjust this value as needed
            cueImageView.frame = CGRect(x: 0, y: screenHeight / 2 - cueImageHeight / 2, width: cueImageWidth, height: cueImageHeight)
            
            // Make the image view draggable and resizable
            cueImageView.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            cueImageView.addGestureRecognizer(tapGesture)
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            cueImageView.addGestureRecognizer(panGesture)
            
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
            cueImageView.addGestureRecognizer(pinchGesture)
            
            // Add the image view to the view hierarchy
            view.addSubview(cueImageView)
            
            // Ensure the cue view is above all other views
            view.bringSubviewToFront(cueImageView)
            
            // Initialize controls container
            let containerWidth: CGFloat = screenWidth / 1.5
            let containerHeight: CGFloat = 150
            controlsContainer = UIView(frame: CGRect(x: screenWidth / 2 - containerWidth / 2, y: cueImageView.frame.maxY + 20, width: containerWidth, height: containerHeight))
            controlsContainer.backgroundColor = UIColor.white.withAlphaComponent(0.95)
            controlsContainer.layer.cornerRadius = 10
            view.addSubview(controlsContainer)
            
            // Initialize sliders and labels
            alphaSlider = UISlider(frame: CGRect(x: 10, y: 40, width: containerWidth - 20, height: 30))
            alphaSlider.minimumValue = 0
            alphaSlider.maximumValue = 1
            alphaSlider.value = Float(cueImageView.alpha)
            alphaSlider.addTarget(self, action: #selector(alphaSliderValueChanged(_:)), for: .valueChanged)
            controlsContainer.addSubview(alphaSlider)
            
            alphaLabel = UILabel(frame: CGRect(x: 10, y: 10, width: containerWidth - 20, height: 20))
            alphaLabel.textAlignment = .center
            alphaLabel.text = "Alpha"
            controlsContainer.addSubview(alphaLabel)
            
            sizeSlider = UISlider(frame: CGRect(x: 10, y: 90, width: containerWidth - 20, height: 30))
            sizeSlider.minimumValue = Float(cueImageWidth) / 8
            sizeSlider.maximumValue = Float(cueImageWidth) * 3
            sizeSlider.value = Float(cueImageWidth)
            sizeSlider.addTarget(self, action: #selector(sizeSliderValueChanged(_:)), for: .valueChanged)
            controlsContainer.addSubview(sizeSlider)
            
            sizeLabel = UILabel(frame: CGRect(x: 10, y: 70, width: containerWidth - 20, height: 20))
            sizeLabel.textAlignment = .center
            sizeLabel.text = "Size"
            controlsContainer.addSubview(sizeLabel)
            
            // Initialize close button
            closeButton = UIButton(frame: CGRect(x: containerWidth - 30, y: 0, width: 30, height: 30))
            closeButton.setTitle("✕", for: .normal)
            closeButton.setTitleColor(.black, for: .normal)
            closeButton.addTarget(self, action: #selector(closeButtonTapped(_:)), for: .touchUpInside)
            controlsContainer.addSubview(closeButton)
        // Log the subviews to verify the hierarchy
           print("Subviews after adding cueImageView: \(view.subviews)")
        }
    
    @objc func handleTapGesture(_ gesture: UITapGestureRecognizer) {
            controlsContainer.isHidden.toggle()
        }
        
    @objc func alphaSliderValueChanged(_ slider: UISlider) {
        guard let cueImageView = view.subviews.first(where: { $0 is UIImageView }) as? UIImageView else { return }
        cueImageView.alpha = CGFloat(slider.value)
    }
        
    @objc func sizeSliderValueChanged(_ slider: UISlider) {
        guard let cueImageView = view.subviews.first(where: { $0 is UIImageView }) as? UIImageView else { return }
        let newSize = CGFloat(slider.value)
        cueImageView.frame.size = CGSize(width: newSize, height: newSize)
    }
        
    @objc func closeButtonTapped(_ sender: UIButton) {
        controlsContainer.isHidden = true
    }
    
    // Gesture handler for pinch-to-zoom
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let cueImageView = gesture.view else { return }
        
        cueImageView.transform = cueImageView.transform.scaledBy(x: gesture.scale, y: gesture.scale)
        gesture.scale = 1.0
    }

    func saveText() {
           // Save the text to UserDefaults
           UserDefaults.standard.set(textView.text, forKey: "TeleprompterText")
       }

    func loadText() {
        // Load the text from UserDefaults
        if let savedText = UserDefaults.standard.string(forKey: "TeleprompterText") {
            textView.text = savedText
        }
    }
    
    func didToggleStartTimerMode(_ isEnabled: Bool) {
        
    }
    
    func didChangeStartTimerTime(_ timeInterval: TimeInterval) {
        
    }
    
    func didSaveText(_ text: String) {
        textView.text = text
    }
    
    func didToggleTimedSpeechRestriction(_ isEnabled: Bool) {
        
    }
    
    // MARK: GAME CONTROLLER MODE
    @objc func controllerDidConnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            configureController(controller)
        }
    }

    @objc func controllerDidDisconnect(_ notification: Notification) {
        // Handle controller disconnection if necessary
        print ("Game Controller disconnected")
    }
    
    func scrollTextView(by offset: CGFloat) {
        // Calculate the new content offset
        let newOffset = CGPoint(x: textView.contentOffset.x, y: textView.contentOffset.y + offset)
        // Ensure the new offset is within the bounds of the text view content
        let maxOffsetY = textView.contentSize.height - textView.bounds.height
        let clampedOffset = CGPoint(x: newOffset.x, y: min(max(newOffset.y, 0), maxOffsetY))
        textView.setContentOffset(clampedOffset, animated: true)
    }
    
    func handleDpadUpPress() {
        guard !isTimedSpeechEnabled else { return }

        let offset: CGFloat = isReverseModeEnabled ? 25 : -25
        scrollTextView(by: offset)
    }
    func handleDpadDownPress() {
        guard !isTimedSpeechEnabled else { return }

        let offset: CGFloat = isReverseModeEnabled ? -25 : 25
        scrollTextView(by: offset)
    }
    
    func configureController(_ controller: GCController) {
        guard let extendedGamepad = controller.extendedGamepad else { return }

        // Map button presses to actions
        extendedGamepad.dpad.left.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
               // Decrease Speed
                self?.adjustScrollSpeed(by: -2)
            }
        }
        extendedGamepad.dpad.right.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
               // Increase Speed
                self?.adjustScrollSpeed(by: 2)
            }
        }
        extendedGamepad.dpad.up.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                //Scroll up
                self?.handleDpadUpPress()
            }
        }
        extendedGamepad.dpad.down.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                //Scroll down
                self?.handleDpadDownPress()
            }
        }
        extendedGamepad.buttonA.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                //Start/Stop Script
                self?.playButtonTapped(self!.playButton)
            }
        }
        extendedGamepad.buttonB.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
               //Start/Stop Recording
                self?.recordButtonTapped(self!.recordButton)
            }
        }
        extendedGamepad.leftTrigger.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
                //Back to start
                self?.backToStart()
                
            }
        }
        extendedGamepad.rightTrigger.pressedChangedHandler = { [weak self] (button, value, pressed) in
            if pressed {
              //Go to end
                self?.backToEnd()
            }
        }
    }
    
    func backToStart () {
        if !isReverseModeEnabled {
            let screenHeight = UIScreen.main.bounds.height
            let blankSpaceHeight = screenHeight / 3.0
            let offset = CGPoint(x: 0, y: -blankSpaceHeight)
            textView.contentOffset = offset
        } else {
            let screenHeight = UIScreen.main.bounds.height
            let textViewHeight = textView.bounds.height
            let blankSpaceHeight = screenHeight / 3.0

            // Set the content inset
            textView.contentInset = UIEdgeInsets(top: blankSpaceHeight, left: 0, bottom: blankSpaceHeight, right: 0)

            // Set the content offset to start at the bottom
            textView.contentOffset = CGPoint(x: 0, y: textView.contentSize.height - (textView.bounds.size.height - textView.contentInset.bottom))
        }
    }
    
    func backToEnd () {
        if isReverseModeEnabled {
            let screenHeight = UIScreen.main.bounds.height
            let blankSpaceHeight = screenHeight / 3.0
            let offset = CGPoint(x: 0, y: -blankSpaceHeight)
            textView.contentOffset = offset
        } else {
            let screenHeight = UIScreen.main.bounds.height
            let textViewHeight = textView.bounds.height
            let blankSpaceHeight = screenHeight / 3.0

            // Set the content inset
            textView.contentInset = UIEdgeInsets(top: blankSpaceHeight, left: 0, bottom: blankSpaceHeight, right: 0)

            // Set the content offset to start at the bottom
            textView.contentOffset = CGPoint(x: 0, y: textView.contentSize.height - (textView.bounds.size.height - textView.contentInset.bottom))
        }
    }
    
    func showActivityIndicator() {
        containerView.isHidden = false
        activityIndicator.startAnimating()
    }

    func hideActivityIndicator() {
        containerView.isHidden = true
        activityIndicator.stopAnimating()
    }
    
    // MARK: CAMERA CODE:
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Recalculate the frame for the container view to keep it centered
        let containerWidth: CGFloat = 200
        let containerHeight: CGFloat = 150
        let containerX = (view.bounds.width - containerWidth) / 2
        let containerY = (view.bounds.height - containerHeight) / 2
        
        containerView.frame = CGRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight)
        
        // Update the position of the activity indicator
        let indicatorWidth = activityIndicator.frame.width
        let indicatorHeight = activityIndicator.frame.height
        let indicatorX = (containerWidth - indicatorWidth) / 2
        let indicatorY: CGFloat = 20 // 20 points from the top
        
        activityIndicator.frame = CGRect(x: indicatorX, y: indicatorY, width: indicatorWidth, height: indicatorHeight)
        
        // Update the position of the activity label
        let labelX: CGFloat = 10
        let labelY = indicatorY + indicatorHeight + 10
        let labelWidth = containerWidth - 20
        let labelHeight: CGFloat = 40 // Adjust height as needed
        
        activityLabel.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
        
        // Ensure the preview layer is properly sized and positioned
        if let previewLayer = view.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = view.bounds
            print("Preview Layer Frame Updated: \(previewLayer.frame)")
            print("View Bounds: \(view.bounds)")
        }
        
  
    }

    var isRecording = false
        
    @IBAction func recordButtonTapped(_ sender: UIButton) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                handlePhotoLibraryAuthorization()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if granted {
                        DispatchQueue.main.async {
                            self?.recordButtonTapped(sender)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.showPermissionDeniedAlert()
                        }
                    }
                }
            default:
                showPermissionDeniedAlert()
            }
        }
        
    func handlePhotoLibraryAuthorization() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            toggleRecording()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                if status == .authorized {
                    DispatchQueue.main.async {
                        self?.toggleRecording()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        default:
            showPermissionDeniedAlert()
        }
    }
        
        func toggleRecording() {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }

    func startRecording() {
        if captureSession == nil {
            captureSession = AVCaptureSession()
            updateRecordButton(isRecording: true)

            guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("Unable to access front camera")
                return
            }

            guard let microphone = AVCaptureDevice.default(for: .audio) else {
                print("Unable to access microphone")
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: frontCamera)
                let audioInput = try AVCaptureDeviceInput(device: microphone)

                captureSession?.beginConfiguration()

                defer {
                    captureSession?.commitConfiguration()
                }

                if captureSession?.canAddInput(videoInput) == true {
                    captureSession?.addInput(videoInput)
                } else {
                    print("Cannot add video input to capture session")
                    return
                }

                if captureSession?.canAddInput(audioInput) == true {
                    captureSession?.addInput(audioInput)
                } else {
                    print("Cannot add audio input to capture session")
                    return
                }

                videoOutput = AVCaptureMovieFileOutput()
                if captureSession?.canAddOutput(videoOutput!) == true {
                    captureSession?.addOutput(videoOutput!)

                    if let connection = videoOutput?.connection(with: .video) {
                        connection.videoOrientation = .portrait
                    }
                } else {
                    print("Cannot add output to capture session")
                    return
                }

            } catch {
                print("Error setting up capture session: \(error.localizedDescription)")
                return
            }

            DispatchQueue.global().async {
                self.captureSession?.startRunning()
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, below: textView.layer)

            textView.alpha = 0.5
        }

        let outputPath = NSTemporaryDirectory() + "output.mov"
        let outputURL = URL(fileURLWithPath: outputPath)
        print("Output URL:", outputURL)

        videoOutput?.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true

        if videoCaptionsEnabled {
            startSpeechRecognition()
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        videoOutput?.stopRecording()
        captureSession?.stopRunning()
        captureSession = nil
        textView.alpha = 1.0
        isRecording = false
        updateRecordButton(isRecording: false)

        if videoCaptionsEnabled {
            stopSpeechRecognition()
        }

        guard let videoOutput = videoOutput, let outputURL = videoOutput.outputFileURL else {
            print("Error: No output URL found.")
            return
        }

        // Start activity indicator
            
        showActivityIndicator()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let currentDate = dateFormatter.string(from: Date())
        let uniqueFileName = "video_\(currentDate).mp4"
        
        // Get the URL for the Documents directory
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let destinationURL = documentsDirectory.appendingPathComponent(uniqueFileName)
            
            do {
                try FileManager.default.moveItem(at: outputURL, to: destinationURL)
                print("Video moved to: \(destinationURL)")

                if videoCaptionsEnabled {
                    overlayCaptionOnVideo(videoURL: destinationURL) { result in
                        switch result {
                        case .success(let url):
                            print("Video with captions saved at: \(url)")
                            DispatchQueue.main.async {
                                self.promptToSaveVideo(url: url)
                            }
                        case .failure(let error):
                            print("Failed to overlay captions on video: \(error)")
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.promptToSaveVideo(url: destinationURL)
                    }
                }
            } catch {
                print("Error moving recorded video: \(error.localizedDescription)")
            }
        }
    }

    func promptToSaveVideo(url: URL) {
        DispatchQueue.main.async {
            self.hideActivityIndicator()// Stop the activity indicator

            let alertController = UIAlertController(title: "Save Video?", message: "Do you want to save the recorded video?", preferredStyle: .alert)
            let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
                self?.saveVideoToPhotoLibrary(url: url)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                self?.resetUI()
            }
            alertController.addAction(saveAction)
            alertController.addAction(cancelAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func saveVideoToPhotoLibrary(url: URL) {
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { saved, error in
                if let error = error {
                    print("Error saving video to photo library: \(error)")
                } else {
                    print("Video saved to photo library.")
                }
                self.resetUI()
            }
        }
    }

    func resetUI() {
        DispatchQueue.main.async {
            if let layers = self.view.layer.sublayers {
                for layer in layers {
                    if layer is AVCaptureVideoPreviewLayer {
                        layer.removeFromSuperlayer()
                    }
                }
            }
            self.textView.alpha = 1.0
        }
    }

    func startSpeechRecognition() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.captionsTextView.text = result.bestTranscription.formattedString // Only update captionsTextView
                isFinal = result.isFinal
            }
           
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.captionsTextView.isHidden = true // Hide the captions text view when recording stops
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }
       
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            captionsTextView.isHidden = true // Hide the captions text view when recording starts
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
    }

    func stopSpeechRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    func overlayCaptionOnVideo(videoURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(.failure(NSError(domain: "No video track", code: -1, userInfo: nil)))
            DispatchQueue.main.async {
                self.hideActivityIndicator()
            }
            return
        }

        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            completion(.failure(NSError(domain: "No audio track", code: -2, userInfo: nil)))
            DispatchQueue.main.async {
                self.hideActivityIndicator()
            }
            return
        }

        // Create video and audio tracks in composition
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "Composition video track creation failed", code: -3, userInfo: nil)))
            DispatchQueue.main.async {
                self.hideActivityIndicator()
            }
            return
        }

        guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            completion(.failure(NSError(domain: "Composition audio track creation failed", code: -4, userInfo: nil)))
            DispatchQueue.main.async {
                self.hideActivityIndicator()
            }
            return
        }

        do {
            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: videoTrack, at: .zero)
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: audioTrack, at: .zero)
        } catch {
            completion(.failure(error))
            DispatchQueue.main.async {
                self.hideActivityIndicator()
            }
            return
        }

        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        let naturalSize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        videoComposition.renderSize = CGSize(width: abs(naturalSize.width), height: abs(naturalSize.height))
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)

        // Apply the preferred transform to fix the orientation
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(videoTrack.preferredTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Create overlay for captions
        let overlayLayer = createDynamicCaptionsLayer(size: videoComposition.renderSize, text: captionsTextView.text, duration: asset.duration)

        // Create parent and video layers
        let parentLayer = CALayer()
        let videoLayer = CALayer()

        parentLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)
        videoLayer.frame = CGRect(origin: .zero, size: videoComposition.renderSize)

        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        // Export the video with captions
        let outputPath = NSTemporaryDirectory() + "output_with_captions_\(Int(Date().timeIntervalSince1970)).mov"
        let outputURL = URL(fileURLWithPath: outputPath)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "Export session creation failed", code: -5, userInfo: nil)))
            DispatchQueue.main.async {
                self.hideActivityIndicator()
            }
            return
        }

        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        exportSession.exportAsynchronously {
            if let error = exportSession.error {
                completion(.failure(error))
                DispatchQueue.main.async {
                    self.hideActivityIndicator()
                }
            } else {
                print("Export session completed successfully with duration: \(CMTimeGetSeconds(asset.duration))")
                completion(.success(outputURL))
            }
        }
    }

    class AnimationDelegate: NSObject, CAAnimationDelegate {
        func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
            print("Animation finished: \(flag)")
        }
    }

    func createDynamicCaptionsLayer(size: CGSize, text: String, duration: CMTime) -> CALayer {
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)
        
        let textLayer = CATextLayer()
        textLayer.font = UIFont.boldSystemFont(ofSize: 70)
        textLayer.fontSize = 70
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.75).cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.cornerRadius = 10
        textLayer.masksToBounds = true
        textLayer.isWrapped = true
        
        // Calculating the padding and adjusting the frame
       let horizontalPadding: CGFloat = size.width * 0.10
        let textLayerHeight: CGFloat = 300
        let bottomMargin: CGFloat = size.height * 0.75
        textLayer.frame = CGRect(x: horizontalPadding, y: size.height - bottomMargin - textLayerHeight, width: size.width - 2 * horizontalPadding, height: textLayerHeight)
        textLayer.bounds = CGRect(x: 0, y: 0, width: size.width - 2 * horizontalPadding, height: textLayerHeight)
        textLayer.position = CGPoint(x: size.width / 2, y: size.height - bottomMargin - textLayerHeight / 2)

        let segments = getCaptionSegments(from: text, groupSize: 7)
        let keyTimes = getKeyTimes(for: segments.count, duration: duration)
        
        print("Recorded duration = \(CMTimeGetSeconds(duration))")
        print("Final keyTimesArray: \(keyTimes)")
        print("Final valuesArray: \(segments)")
        print("Segments count: \(segments.count), KeyTimes count: \(keyTimes.count)")

        // Animation setup with delegate
        let animationDelegate = AnimationDelegate()
        
        let animation = CAKeyframeAnimation(keyPath: "string")
        animation.values = segments
        animation.keyTimes = keyTimes
        animation.duration = CMTimeGetSeconds(duration)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        animation.delegate = animationDelegate // Set the delegate
        
        textLayer.add(animation, forKey: "string")

        overlayLayer.addSublayer(textLayer)
        return overlayLayer
    }
        
    func getCaptionSegments(from text: String, groupSize: Int) -> [String] {
        let words = text.split(separator: " ").map { String($0) }
        var segments = [String]()
        
        if words.isEmpty {
            return segments
        }
        
        for i in stride(from: 0, to: words.count, by: groupSize) {
            let end = min(i + groupSize, words.count)
            let currentSegment = words[i..<end].joined(separator: " ")
            segments.append(currentSegment)
        }
        
        // Log segments for debugging
        print("Segments: \(segments)")
        return segments
    }

    func getKeyTimes(for segmentCount: Int, duration: CMTime) -> [NSNumber] {
        guard segmentCount > 0 else {
            return [0.0, 1.0] // Return start and end key times if no segments are present
        }

        let totalDurationInSeconds = CMTimeGetSeconds(duration)
        let effectiveDuration = totalDurationInSeconds * 0.90 // Use 90% of the total duration
        let timeInterval = effectiveDuration / Double(segmentCount * 2)

        var keyTimes = [NSNumber]()
        for i in 0..<segmentCount {
            keyTimes.append(NSNumber(value: Double(i) * timeInterval / totalDurationInSeconds))
        }

        keyTimes.append(NSNumber(value: effectiveDuration / totalDurationInSeconds)) // Ensure the last segment ends slightly before the video ends

        // Log key times for debugging
        print("Key times: \(keyTimes)")
        return keyTimes
    }

    func createCaptionsLayer(size: CGSize, text: String?) -> CALayer {
        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.font = UIFont.systemFont(ofSize: 40)
        textLayer.foregroundColor = UIColor.white.cgColor
        textLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        textLayer.alignmentMode = .center
        textLayer.frame = CGRect(x: 0, y: size.height - 100, width: size.width, height: 100)
        textLayer.contentsScale = UIScreen.main.scale
        
        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)
        overlayLayer.addSublayer(textLayer)
        
        return overlayLayer
    }

    func generateCaptionOverlay(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor.black.withAlphaComponent(0.5)
            ]
            let text = self.captionsTextView.text ?? ""
            let textRect = CGRect(x: 0, y: size.height - 100, width: size.width, height: 100)
            text.draw(in: textRect, withAttributes: textAttributes)
        }
    }
    
    func showPermissionDeniedAlert() {
            let alertController = UIAlertController(title: "Permission Denied", message: "To save videos, please grant permission to access the camera and photo library in Settings.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }

extension ViewController: AVCaptureFileOutputRecordingDelegate {
  
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
           print("Started recording to: \(fileURL)")
           updateRecordButton(isRecording: true)
       }

       func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
           print("Finished recording to: \(outputFileURL)")
           updateRecordButton(isRecording: false)
       }
    

    func updateRecordButton(isRecording: Bool) {
        if isRecording {
            recordButton.setImage(recordingImage, for: .normal)
            flashButton(button: recordButton)
        } else {
            recordButton.setImage(notRecordingImage, for: .normal)
            stopFlashingButton(button: recordButton)
        }
    }

   
        
    func flashButton(button: UIButton) {
        // Remove any existing overlay view
        overlayView?.removeFromSuperview()
        
        // Create and configure a new overlay view
        overlayView = UIView(frame: button.bounds)
        overlayView?.backgroundColor = .red
        overlayView?.alpha = 0
        overlayView?.layer.cornerRadius = button.layer.cornerRadius
        overlayView?.isUserInteractionEnabled = false // Ensure the overlay view ignores touch events
        button.addSubview(overlayView!)
        
        UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction], animations: {
            self.overlayView?.alpha = 1
        }, completion: nil)
    }

    func stopFlashingButton(button: UIButton) {
        overlayView?.layer.removeAllAnimations()
        overlayView?.removeFromSuperview()
        overlayView = nil
        button.backgroundColor = .darkGray // Reset to original color
    }


        
        
        @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer) {
            if let error = error {
                print("Error saving video: \(error.localizedDescription)")
            } else {
                print("Video saved successfully")
            }
        }
    }

extension UIColor {
    var hexString: String {
        guard let components = cgColor.components, components.count >= 3 else { return "" }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

extension UITextView {
    func currentLineHeight() -> CGFloat {
        guard let attributedText = attributedText else { return 0 }

        let textStorage = NSTextStorage(attributedString: attributedText)
        let textContainer = NSTextContainer(size: bounds.size)
        let layoutManager = NSLayoutManager()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let range = NSRange(location: 0, length: attributedText.length)
        layoutManager.ensureLayout(for: textContainer)
        let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: range.location, effectiveRange: nil)

        return lineRect.height
    }
}

class CustomPiPView: NewUIPiPView {
    
    var playerLayer: AVPlayerLayer?
    var player: AVPlayer?
    var timer: Timer?
    var audioPlayer: AVAudioPlayer?
    // Scrolling speed property
    var scrollingSpeed: Double = 50.0 // Default scrolling speed
    
    private var viewController: ViewController?
  
    var selectedBackgroundAudio: BackgroundAudioOption = .none
    
    func setViewController(_ viewController: ViewController) {
        self.viewController = viewController
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        // Register to observe notifications
        NotificationCenter.default.addObserver(self, selector: #selector(startScrolling), name: .startScrollingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopScrolling), name: .stopScrollingNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
        // Register to observe notifications
        NotificationCenter.default.addObserver(self, selector: #selector(startScrolling), name: .startScrollingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopScrolling), name: .stopScrollingNotification, object: nil)
    }
    
    override func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        super.pictureInPictureControllerWillStartPictureInPicture(pictureInPictureController)
        pictureInPictureController.requiresLinearPlayback = true
        // Call startScrolling when PiP starts
        startBackgroundAudio()
        startScrolling()
    }
    
    override func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        super.pictureInPictureControllerDidStartPictureInPicture(pictureInPictureController)
        startBackgroundAudio()
        print ("Called Did Start PiP")
    }
    
    @objc public func startScrolling() {
        // Start background audio if it's not already playing and a background audio option is selected
        if selectedBackgroundAudio != .none && (audioPlayer == nil || !(audioPlayer?.isPlaying ?? false)) {
            startBackgroundAudio()
        }

        // Start the scrolling timer
        timer = Timer(timeInterval: 1.0 / scrollingSpeed, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scrollTextView()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func startBackgroundAudio() {
        guard selectedBackgroundAudio != .none else {
            print("No background audio selected")
            return
        }
        
        let audioFileName = selectedBackgroundAudio == .metronome ? "metronome" : nil
        if let audioFileName = audioFileName, let audioFilePath = Bundle.main.path(forResource: audioFileName, ofType: "mp3") {
            let audioURL = URL(fileURLWithPath: audioFilePath)
            print("Audio file path: \(audioFilePath)")
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.numberOfLoops = -1 // Loop indefinitely
                audioPlayer?.play()
                print("Audio player started playing")
            } catch {
                print("Error playing background audio: \(error)")
            }
        } else {
            print("Audio file not found")
        }
    }
    
    func stopBackgroundAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        print("Background audio stopped")
    }
    
    @objc public func stopScrolling() {
        // Stop scrolling timer
        stopBackgroundAudio()
        timer?.invalidate()
    }
    
    public func scrollTextView() {
        // Implement scrolling logic here
        // For example, adjust the content offset of the text view
        let newOffset = CGPoint(x: textView.contentOffset.x, y: textView.contentOffset.y + 1)
        textView.setContentOffset(newOffset, animated: false)
    }
    
    // Add scriptContent property
    var scriptContent: String? {
        didSet {
            // Update text content when scriptContent changes
            print("Received script content:", scriptContent ?? "No content received")
            textView.text = scriptContent
        }
    }
    
    let textView = UITextView()
    let slider = UISlider()
    
    private func setupSubviews() {
        // Setup textView
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        
        NSLayoutConstraint.activate([
            // Position the textView with 20-pixel padding on all edges
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
        
        // Call method to set text view properties from UserDefaults
        setupTextViewPropertiesFromUserDefaults()
    }
    
    func setupTextViewPropertiesFromUserDefaults() {
        // Background color
        if let backgroundColorHex = UserDefaults.standard.string(forKey: "BackgroundColor"),
           let backgroundColor = UIColor(hexString: backgroundColorHex) {
            textView.backgroundColor = backgroundColor
        } else {
            // Set default background color to black
            textView.backgroundColor = .black
        }
        
        // Font color
        if let fontColorHex = UserDefaults.standard.string(forKey: "FontColor"),
           let fontColor = UIColor(hexString: fontColorHex) {
            textView.textColor = fontColor
        } else {
            // Set default font color to white
            textView.textColor = .white
        }
        if let initialFontColor = textView.textColor {
            let initialFontColorHex =  initialFontColor.hexString
            UserDefaults.standard.set(initialFontColorHex, forKey: "InitialFontColor")
        }
        
        // Font
        if let fontData = UserDefaults.standard.data(forKey: "SelectedFont"),
           let selectedFont = NSKeyedUnarchiver.unarchiveObject(with: fontData) as? UIFont {
            textView.font = selectedFont
        } else {
            // Set default font to System Semibold with size 48
            textView.font = UIFont.systemFont(ofSize: 48, weight: .semibold)
        }
        
        // Font size (optional, as it's already handled by setting the font)
        
        // Line spacing
        if let savedLineHeight = UserDefaults.standard.value(forKey: "LineSpacing") as? CGFloat {
            setLineSpacing(savedLineHeight)
            print("Saved Line Spacing =", savedLineHeight)
        } else {
            // Set default line spacing to -11
            setLineSpacing(-11.0)
        }
        
        // Text alignment
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
    }
    
    func setLineSpacing(_ lineSpacing: CGFloat) {
        // Ensure textView.font is not nil
        guard textView.font != nil else {
            return
        }
        
        // Create a mutable attributed string with the existing text
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText ?? NSAttributedString())
        
        // Create a paragraph style with the specified line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        // Apply the paragraph style to the entire text range
        mutableAttributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: mutableAttributedString.length))
        
        // Update the attributed text of the textView
        textView.attributedText = mutableAttributedString
    }
}

extension ViewController {
    func removeCue() {
        // Loop through subviews to find and remove the cue image view
        for subview in view.subviews {
            if let cueImageView = subview as? UIImageView {
                cueImageView.removeFromSuperview()
            }
        }
    }
}

func extractText(from data: Data, fileType: String) -> String? {
    if fileType == "docx" {
        do {
            let docx = try AEXMLDocument(xml: data)
            return docx.root["w:document"]["w:body"].string
        } catch {
            print("Failed to parse .docx file: \(error)")
            return nil
        }
    } else if fileType == "pages" {
        // Implement parsing for .pages files
    }
    return String(data: data, encoding: .utf8)
}

//MARK: RevenueCat Paywall
extension ViewController: PaywallViewControllerDelegate {
    func paywallViewController(_ controller: PaywallViewController,
                               didFinishPurchasingWith customerInfo: CustomerInfo) {
        checkPremiumStatus()
    }

}

extension UIViewController {
    func isPremiumUser(completion: @escaping (Bool) -> Void) {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            if let customerInfo = customerInfo, error == nil {
                completion(customerInfo.entitlements.all["Pro Upgrade"]?.isActive == true)
                print ("User has purchased upgrade")
            } else {
                completion(false)
                print ("User has not purchased upgrade")
            }
        }
    }
}
extension ViewController: EditScriptDelegate {
    func updateScript(_ script: Script) {
        self.currentScript = script
        self.textView.text = script.content
        // Save the last opened script
        UserDefaults.standard.saveLastOpenedScript(script)
    }
}

extension UIView {
    func hierarchyDescription(indent: String = "") -> String {
        var description = "\(indent)\(self) \n"
        let subviewIndent = indent + "    "
        for subview in subviews {
            description += subview.hierarchyDescription(indent: subviewIndent)
        }
        return description
    }
}

extension UITextView {
    func visibleLines() -> [String] {
        guard let text = self.text else { return [] }
        
        // Get the visible rectangle
        let visibleRect = self.bounds
        let visibleGlyphRange = self.layoutManager.glyphRange(forBoundingRect: visibleRect, in: self.textContainer)
        
        // Get the lines
        var lines: [String] = []
        self.layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { (rect, usedRect, textContainer, glyphRange, stop) in
            let characterRange = self.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineText = (text as NSString).substring(with: characterRange)
            lines.append(lineText)
        }
        
        return lines
    }
}

extension ViewController: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Interstitial ad dismissed.")
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Failed to present interstitial ad: \(error)")
    }
}

