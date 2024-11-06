import UIKit

class ScriptCell: UICollectionViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentPreviewLabel: UILabel!
    @IBOutlet weak var deleteButton: UIButton!

    var deleteAction: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        deleteButton.isHidden = true // Initially hidden
    }
    
    func startWobble() {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.fromValue = -0.05
        animation.toValue = 0.05
        animation.autoreverses = true
        animation.duration = 0.1
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "wobble")
        showDeleteButton()
    }

    func stopWobble() {
        layer.removeAnimation(forKey: "wobble")
        hideDeleteButton()
    }

    @objc private func deleteButtonTapped() {
        deleteAction?()
    }

    func configure(with script: Script) {
        titleLabel.text = script.title
        
        // Show a preview of the script's content
        let previewLength = 100 // Adjust the number of characters to show
        let previewText = String(script.content.prefix(previewLength))
        contentPreviewLabel.text = previewText + (script.content.count > previewLength ? "..." : "")
    }

    func showDeleteButton() {
        deleteButton.isHidden = false
        deleteButton.tintColor = .red
    }

    func hideDeleteButton() {
        deleteButton.isHidden = true
    }
}
