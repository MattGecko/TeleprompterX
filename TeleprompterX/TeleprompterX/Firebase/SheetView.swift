import SwiftUI

struct SheetView<Content: View>: UIViewControllerRepresentable {
    var content: Content
    let detents: [UISheetPresentationController.Detent]
    
    init(detents: [UISheetPresentationController.Detent], @ViewBuilder content: () -> Content) {
        self.content = content()
        self.detents = detents
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let childView = UIHostingController(rootView: content)
        
        viewController.addChild(childView)
        viewController.view.addSubview(childView.view)
        
        childView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            childView.view.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            childView.view.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor),
            childView.view.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            childView.view.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
        ])
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let sheet = uiViewController.sheetPresentationController else { return }
        sheet.detents = detents
        sheet.prefersGrabberVisible = true
    }
    
    class Coordinator: NSObject, UISheetPresentationControllerDelegate {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}
