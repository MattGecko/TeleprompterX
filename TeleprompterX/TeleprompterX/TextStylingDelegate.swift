// TextStylingDelegate.swift

import UIKit

protocol TextStylingDelegate: AnyObject {
    func updateFloatingTextView(withText text: String, font: UIFont, textColor: UIColor, backgroundColor: UIColor)
}
