import UIKit
import WebKit
import Network

class SuggestFeatureViewController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView!
    let monitor = NWPathMonitor()
    var isConnected = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize and configure the WKWebView
        webView = WKWebView()
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Monitor network connectivity
        monitor.pathUpdateHandler = { path in
            self.isConnected = path.status == .satisfied
            DispatchQueue.main.async {
                if self.isConnected {
                    self.loadSuggestionPage()
                } else {
                    self.showNetworkError()
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)

        // Set up constraints for the web view
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Create the toolbar
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        // Set up constraints for the toolbar
        NSLayoutConstraint.activate([
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Create toolbar items
        let backButton = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(goBack))
        let refreshButton = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(refresh))
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
        
        // Flexible space item to align buttons properly
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // Add items to the toolbar
        toolbar.setItems([backButton, flexibleSpace, refreshButton, flexibleSpace, doneButton], animated: false)
    }
    
    // Load the suggestion page
    func loadSuggestionPage() {
        if let url = URL(string: "https://insigh.to/b/teleprompter-x") {
            webView.load(URLRequest(url: url))
        }
    }

    // Show network error alert
    func showNetworkError() {
        let alert = UIAlertController(title: "Network Error", message: "Unable to load the suggestion page. Please check your internet connection and try again.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    // Back button action
    @objc func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    // Refresh button action
    @objc func refresh() {
        if isConnected {
            webView.reload()
        } else {
            showNetworkError()
        }
    }
    
    // Done button action
    @objc func done() {
        dismiss(animated: true, completion: nil)
    }
    
    // WKNavigationDelegate method to know when the page has finished loading
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // JavaScript to remove the footer
        let js = "document.querySelector('footer').style.display='none';"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
