import UIKit

class FloatingWindowViewController: UIViewController {

    var scriptContent: String?
    var textView: UITextView!
    var closeButton: UIButton!
    var videoURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create and configure the text view
        textView = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        textView.isEditable = false
        textView.text = scriptContent
        view.addSubview(textView)

        // Create and configure the close button
        closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // Layout
        textView.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),

            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 20)
        ])

        // Make the window draggable
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)
    }
    
    // Method to update the text view with new styling
       func updateTextView(withText text: String, font: UIFont, textColor: UIColor, backgroundColor: UIColor) {
           textView.text = text
           textView.font = font
           textView.textColor = textColor
           textView.backgroundColor = backgroundColor
       }

    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        view.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
        gesture.setTranslation(.zero, in: view)
    }

}
