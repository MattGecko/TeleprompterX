import UIKit

class FloatingScriptViewController: UIViewController {
    var scriptContent: String = ""
    var scrollSpeed: Double = 50

    private var textView: UITextView!
    private var playButton: UIButton!
    private var pauseButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.clear

        setupTextView()
        setupButtons()
    }

    private func setupTextView() {
        textView = UITextView(frame: CGRect(x: 20, y: 100, width: view.frame.width - 40, height: view.frame.height - 200))
        textView.text = scriptContent
        textView.isEditable = false
        textView.backgroundColor = UIColor.clear
        view.addSubview(textView)
    }

    private func setupButtons() {
        playButton = UIButton(type: .system)
        playButton.setTitle("Play", for: .normal)
        playButton.frame = CGRect(x: 20, y: view.frame.height - 80, width: 60, height: 40)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        view.addSubview(playButton)

        pauseButton = UIButton(type: .system)
        pauseButton.setTitle("Pause", for: .normal)
        pauseButton.frame = CGRect(x: 100, y: view.frame.height - 80, width: 60, height: 40)
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        view.addSubview(pauseButton)
    }

    @objc private func playButtonTapped() {
        // Start scrolling text
    }

    @objc private func pauseButtonTapped() {
        // Pause scrolling text
    }
}
