import UIKit

class FloatingWindow: UIWindow {

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Customize the window appearance
        self.backgroundColor = UIColor.clear
        self.windowLevel = .alert // Ensure the window appears above other app windows
        self.isHidden = false

        // Create and configure the floating window view controller
        let floatingViewController = FloatingWindowViewController()
        self.rootViewController = floatingViewController
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Override hitTest(_:with:) to allow user interaction with the floating window
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView == self {
            return nil // Disallow touches on the window itself, allowing interaction with underlying views
        }
        return hitView
    }
}
