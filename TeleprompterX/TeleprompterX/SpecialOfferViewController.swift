import Foundation
import UIKit
import RevenueCat

protocol SpecialOfferViewControllerDelegate: AnyObject {
    func didCompletePurchase()
}


class SpecialOfferViewController: UIViewController {
    
    @IBOutlet weak var productPriceLabel: UILabel!
    @IBOutlet weak var purchaseButton: UIButton!
    weak var delegate: SpecialOfferViewControllerDelegate?
    var product: Package?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchOfferings()
    }
    
    func fetchOfferings() {
        Purchases.shared.getOfferings { (offerings, error) in
            if let offerings = offerings, let discountedOffering = offerings["DiscountedOffering"] {
                self.product = discountedOffering.availablePackages.first
                self.updateUI()
            } else if let error = error {
                print("Error fetching offerings: \(error.localizedDescription)")
            }
        }
    }
    
    func updateUI() {
        guard let product = product else { return }
        productPriceLabel.text = "Just \(product.storeProduct.localizedPriceString)"
        purchaseButton.setTitle("Upgrade to Pro for \(product.storeProduct.localizedPriceString)", for: .normal)
    }
    
    @IBAction func purchaseButtonTapped(_ sender: UIButton) {
        guard let product = product else { return }
        purchase(product: product)
    }
    
    func purchase(product: Package) {
        Purchases.shared.purchase(package: product) { (transaction, customerInfo, error, userCancelled) in
            if let error = error {
                print("Purchase failed: \(error.localizedDescription)")
            } else if userCancelled {
                print("User cancelled the purchase")
            } else {
                if let customerInfo = customerInfo, customerInfo.entitlements["Pro Upgrade"]?.isActive == true {
                    print("ProUpgrade is active")
                    DispatchQueue.main.async {
                        self.delegate?.didCompletePurchase()
                        self.dismiss(animated: true, completion: nil)
                    }
                } else {
                    print("ProUpgrade entitlement is not active")
                }
            }
        }
    }

    @IBAction func restoreButtonTapped(_ sender: UIButton) {
        Purchases.shared.restorePurchases { (customerInfo, error) in
            if let error = error {
                print("Restore failed: \(error.localizedDescription)")
            } else {
                if let customerInfo = customerInfo, customerInfo.entitlements["Pro Upgrade"]?.isActive == true {
                    print("ProUpgrade is active")
                    DispatchQueue.main.async {
                        self.delegate?.didCompletePurchase()
                        self.dismiss(animated: true, completion: nil)
                    }
                } else {
                    print("ProUpgrade entitlement is not active after restore")
                }
            }
        }
    }

    @IBAction func loadTerms(_ sender: UIButton) {
        if let url = URL(string: "https://teleprompterpro2.com/terms.html") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func loadPrivacy(_ sender: UIButton) {
        if let url = URL(string: "https://teleprompterpro2.com/privacy.html") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
