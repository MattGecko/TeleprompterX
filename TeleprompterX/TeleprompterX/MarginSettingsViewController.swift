import UIKit

protocol MarginSettingsVisibilityDelegate: AnyObject {
    func didPresentMarginSettings()
    func didDismissMarginSettings()
    func didUpdateMargins(top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat)
}

class MarginSettingsViewController: UIViewController {
    weak var visibilityDelegate: MarginSettingsVisibilityDelegate?
    var onSave: ((CGFloat, CGFloat, CGFloat, CGFloat) -> Void)?
    var topMargin: CGFloat = 0
    var bottomMargin: CGFloat = 0
    var leftMargin: CGFloat = 0
    var rightMargin: CGFloat = 0

    private let containerView = UIView()
    private let topSlider = UISlider()
    private let bottomSlider = UISlider()
    private let leftSlider = UISlider()
    private let rightSlider = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        view.alpha = 0.6
        setupContainerView()
        setupTitle()
        setupSliders()
        setupLabels()
        setupResetButton()
        setupDismissButton()
        visibilityDelegate?.didPresentMarginSettings()
    }

    private func setupContainerView() {
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        containerView.layer.cornerRadius = 15
        containerView.layer.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
           // containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 300),
            containerView.heightAnchor.constraint(equalToConstant: 400)
        ])
    }

    private func setupTitle() {
        let titleLabel = UILabel()
        titleLabel.text = "Editing Margins"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }

    private func setupSliders() {
        configureSlider(topSlider, value: Float(topMargin), tag: 1)
        configureSlider(bottomSlider, value: Float(bottomMargin), tag: 2)
        configureSlider(leftSlider, value: Float(leftMargin), tag: 3)
        configureSlider(rightSlider, value: Float(rightMargin), tag: 4)
    }

    private func configureSlider(_ slider: UISlider, value: Float, tag: Int) {
        slider.maximumValue = 300
        slider.minimumValue = 0
        slider.value = value
        slider.tag = tag
        slider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupLabels() {
        let topLabel = createLabel(withText: "TOP")
        let bottomLabel = createLabel(withText: "BOTTOM")
        let leftLabel = createLabel(withText: "LEFT")
        let rightLabel = createLabel(withText: "RIGHT")

        let stackView = UIStackView(arrangedSubviews: [
            createSliderStackView(titleLabel: topLabel, slider: topSlider, tag: 5),
            createSliderStackView(titleLabel: bottomLabel, slider: bottomSlider, tag: 6),
            createSliderStackView(titleLabel: leftLabel, slider: leftSlider, tag: 7),
            createSliderStackView(titleLabel: rightLabel, slider: rightSlider, tag: 8)
        ])
        stackView.axis = .vertical
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 50)
        ])
    }

    private func createLabel(withText text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createSliderStackView(titleLabel: UILabel, slider: UISlider, tag: Int) -> UIStackView {
        let valueLabel = UILabel()
        valueLabel.text = "\(Int(slider.value))"
        valueLabel.tag = tag
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let labelStackView = UIStackView(arrangedSubviews: [titleLabel])
        labelStackView.axis = .horizontal
        labelStackView.spacing = 10
        labelStackView.alignment = .center
        labelStackView.translatesAutoresizingMaskIntoConstraints = false

        let sliderStackView = UIStackView(arrangedSubviews: [slider, valueLabel])
        sliderStackView.axis = .horizontal
        sliderStackView.spacing = 10
        sliderStackView.alignment = .center
        sliderStackView.distribution = .fillProportionally
        sliderStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [labelStackView, sliderStackView])
        stackView.axis = .vertical
        stackView.spacing = 5
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
                   slider.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 0.8),  // Adjust the width of the slider
                   valueLabel.widthAnchor.constraint(equalToConstant: 50) // Ensure value label does not push off the screen
               ])

        return stackView
    }

    private func setupResetButton() {
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(resetButton)
        NSLayoutConstraint.activate([
            resetButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40),
            resetButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }

    private func setupDismissButton() {
        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Done", for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(dismissButton)
        NSLayoutConstraint.activate([
            dismissButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            dismissButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
    }

    @objc private func resetButtonTapped() {
        topMargin = 0
        bottomMargin = 0
        leftMargin = 0
        rightMargin = 0

        topSlider.value = 0
        bottomSlider.value = 0
        leftSlider.value = 0
        rightSlider.value = 0

        updateValueLabels()
        NotificationCenter.default.post(name: NSNotification.Name("MarginsUpdated"), object: nil, userInfo: [
            "top": topMargin,
            "bottom": bottomMargin,
            "left": leftMargin,
            "right": rightMargin
        ])
        visibilityDelegate?.didUpdateMargins(top: topMargin, bottom: bottomMargin, left: leftMargin, right: rightMargin)
    }

    @objc private func dismissButtonTapped() {
        saveMarginsToDefaults()
        onSave?(topMargin, bottomMargin, leftMargin, rightMargin)
        NotificationCenter.default.post(name: NSNotification.Name("MarginsUpdated"), object: nil, userInfo: [
            "top": topMargin,
            "bottom": bottomMargin,
            "left": leftMargin,
            "right": rightMargin
        ])
        visibilityDelegate?.didDismissMarginSettings()
        dismiss(animated: true, completion: nil)
    }

    @objc private func sliderValueChanged(_ sender: UISlider) {
        let value = CGFloat(sender.value)
        let labelTag = sender.tag + 4

        if let label = containerView.viewWithTag(labelTag) as? UILabel {
            label.text = "\(Int(value))"
        }

        switch sender {
        case topSlider:
            topMargin = value
        case bottomSlider:
            bottomMargin = value
        case leftSlider:
            leftMargin = value
        case rightSlider:
            rightMargin = value
        default:
            break
        }

        NotificationCenter.default.post(name: NSNotification.Name("MarginsUpdated"), object: nil, userInfo: [
            "top": topMargin,
            "bottom": bottomMargin,
            "left": leftMargin,
            "right": rightMargin
        ])
        visibilityDelegate?.didUpdateMargins(top: topMargin, bottom: bottomMargin, left: leftMargin, right: rightMargin)
    }

    private func updateValueLabels() {
        if let topLabel = containerView.viewWithTag(5) as? UILabel {
            topLabel.text = "0"
        }
        if let bottomLabel = containerView.viewWithTag(6) as? UILabel {
            bottomLabel.text = "0"
        }
        if let leftLabel = containerView.viewWithTag(7) as? UILabel {
            leftLabel.text = "0"
        }
        if let rightLabel = containerView.viewWithTag(8) as? UILabel {
            rightLabel.text = "0"
        }
    }

    private func saveMarginsToDefaults() {
        UserDefaults.standard.set(topMargin, forKey: "TopMargin")
        UserDefaults.standard.set(bottomMargin, forKey: "BottomMargin")
        UserDefaults.standard.set(leftMargin, forKey: "LeftMargin")
        UserDefaults.standard.set(rightMargin, forKey: "RightMargin")
    }

    private func loadMarginsFromDefaults() {
        topMargin = CGFloat(UserDefaults.standard.float(forKey: "TopMargin"))
        bottomMargin = CGFloat(UserDefaults.standard.float(forKey: "BottomMargin"))
        leftMargin = CGFloat(UserDefaults.standard.float(forKey: "LeftMargin"))
        rightMargin = CGFloat(UserDefaults.standard.float(forKey: "RightMargin"))
    }
}
