import UIKit
import MessageUI

class SecretUpgradeOfferViewController: UIViewController, MFMailComposeViewControllerDelegate {

    override func viewDidLoad() {
          super.viewDidLoad()

          // Debugging print statements
          print("SecretUpgradeOfferViewController loaded")
          
        
      }
    
    @objc func sendEmailButtonTapped() {
        sendEmail()
    }
    
    @IBAction func Email(_ sender: Any) {
        
        // Check if the device is capable of sending email
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertController(title: "Cannot Send Email", message: "Your device is not configured to send emails.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        // Configure the mail compose view controller
        let mailComposeVC = MFMailComposeViewController()
        mailComposeVC.mailComposeDelegate = self
        mailComposeVC.setToRecipients(["hello@mattcowlin.com"])
        mailComposeVC.setSubject("Hello!")
        mailComposeVC.setMessageBody("I have followed the steps in Teleprompter X and would like 90% Off an upgrade please.", isHTML: false)
        
        // Present the mail compose view controller
        present(mailComposeVC, animated: true, completion: nil)
        
        
    }
    
    
    func sendEmail() {
     
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
        
        switch result {
        case .cancelled:
            print("Mail cancelled")
        case .saved:
            print("Mail saved")
        case .sent:
            print("Mail sent")
        case .failed:
            print("Mail failed: \(error?.localizedDescription ?? "unknown error")")
        @unknown default:
            fatalError()
        }
    }
}
