//
//  ViewController.swift
//  UniversalWebview
//
//  Created by Mario Kovacevic on 05/08/2016.
//  Copyright (c) 2016 Brommko LLC. All rights reserved.
//

import UIKit
import WebKit
import MBProgressHUD
import GoogleMobileAds
import SwiftyUserDefaults
import SwiftyStoreKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, MBProgressHUDDelegate, GADBannerViewDelegate, GADInterstitialDelegate  {
    
    @IBOutlet weak var backgroundImage: UIImageView?

    var bannerView: GADBannerView?
    var toolbar:UIToolbar?
    var backButton: UIBarButtonItem?
    var forwardButton: UIBarButtonItem?
    var iapButton: UIBarButtonItem?
    var reloadButton: UIBarButtonItem?
    
    var mainURL:URL?
    var wkWebView: WKWebView?
    var popViewController:UIViewController?
    var load : MBProgressHUD = MBProgressHUD()
    var interstitial: GADInterstitial!
    let request = GADRequest()
    
    var timer:Timer!
    var showInterstitialInSecoundsEvery:Int! = 60
    var count:Int = 60
    var interstitialShownForFirstTime = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.request.testDevices = ["bb394635b98430350b538d1e2ea1e9d6", kGADSimulatorID];
        
        self.loadToolbar()
        self.loadInterstitalAd()
        self.loadBannerAd()
        self.loadWebView()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.loadWebView), name:NSNotification.Name(rawValue: "RefreshSite"), object: nil)
        
        let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
        if let secounds = appData?.value(forKey: "ShowInterstitialInSecoundsEvery") as? String {
            self.showInterstitialInSecoundsEvery = Int(secounds)!
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.counterForInterstitialAd), userInfo: nil, repeats: true)
        }
    }
    
    func showLoader() {
        self.load = MBProgressHUD.showAdded(to: self.view, animated: true)
        self.load.mode = MBProgressHUDMode.indeterminate
    }
    
    func loadToolbar() {
        self.toolbar = self.getToolbar()
        self.backButton?.isEnabled = false
        self.forwardButton?.isEnabled = false
    }
    
    func back() {
        _ = self.wkWebView?.goBack()
    }
    
    func forward() {
        _ = self.wkWebView?.goForward()
    }
    
    func reload() {
        if let URL = self.wkWebView?.url {
            self.showLoader()
            let request = URLRequest(url: URL)
            _ = self.wkWebView?.load(request)
        }
    }
    
    func loadWebView() {
        self.getURL()
        self.loadWebSite()
    }
    
    func getURL() {
        let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
        let urlString = appData?.value(forKey: "URL") as? String
        
        if let URL = UserDefaults.standard.string(forKey: "URL") {
            self.mainURL = Foundation.URL(string: URL)
        }
        
        if self.mainURL == nil {
            if urlString != nil {
                self.mainURL = URL(string: urlString!)
            }
        }
    }
    
    func loadWebSite() {
        
        let theConfiguration:WKWebViewConfiguration? = WKWebViewConfiguration()
        let thisPref:WKPreferences = WKPreferences()
        thisPref.javaScriptCanOpenWindowsAutomatically = true;
        thisPref.javaScriptEnabled = true
        theConfiguration!.preferences = thisPref;

        self.wkWebView = WKWebView(frame: self.getFrame(), configuration: theConfiguration!)
        if self.mainURL != nil {
            // Create url request
            let requestObj: URLRequest?
            
            if Reachability.isConnectedToNetwork() {
                requestObj = URLRequest(url: self.mainURL!, cachePolicy: NSURLRequest.CachePolicy.returnCacheDataElseLoad, timeoutInterval: 0)
            } else {
                requestObj = URLRequest(url: self.mainURL!, cachePolicy: NSURLRequest.CachePolicy.returnCacheDataDontLoad, timeoutInterval: 0)
            }
            _ = self.wkWebView?.load(requestObj!)
        } else {
            var fileURL = URL(fileURLWithPath: Bundle.main.path(forResource: "www/index", ofType: "html")!)

            if #available(iOS 9.0, *) {
                // iOS9 and above. One year later things are OK.
                _ = self.wkWebView?.loadFileURL(fileURL, allowingReadAccessTo: fileURL)
            } else {
                // iOS8. Things can (sometimes) be workaround-ed
                //   Brave people can do just this
                //   fileURL = try! pathForBuggyWKWebView8(fileURL: fileURL)
                //   webView.load(URLRequest(url: fileURL))
                do {
                    fileURL = try fileURLForBuggyWKWebView8(fileURL: fileURL)
                    _ = self.wkWebView?.load(URLRequest(url: fileURL))
                } catch let error as NSError {
                    print("Error: " + error.debugDescription)
                }
            }
        }
        
        self.wkWebView?.navigationDelegate = self
        self.wkWebView?.uiDelegate = self
        self.wkWebView?.addObserver(self, forKeyPath: "loading", options: .new, context: nil)
    }
    
    func fileURLForBuggyWKWebView8(fileURL: URL) throws -> URL {
        // Some safety checks
        if !fileURL.isFileURL {
            throw NSError(
                domain: "BuggyWKWebViewDomain",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("URL must be a file URL.", comment:"")])
        }
        _ = try! fileURL.checkResourceIsReachable()
        
        // Create "/temp/www" directory
        let fm = FileManager.default
        let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("www")
        try! fm.createDirectory(at: tmpDirURL, withIntermediateDirectories: true, attributes: nil)
        
        // Now copy given file to the temp directory
        let dstURL = tmpDirURL.appendingPathComponent(fileURL.lastPathComponent)
        let _ = try? fm.removeItem(at: dstURL)
        try! fm.copyItem(at: fileURL, to: dstURL)
        
        // Files in "/temp/www" load flawlesly :)
        return dstURL
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (keyPath == "loading") {
            self.backButton?.isEnabled = self.wkWebView!.canGoBack
            self.forwardButton?.isEnabled = self.wkWebView!.canGoForward
        }
    }

    func loadInterstitalAd() {
        if Defaults[.adsPurchased] == false {
            let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
            if let interstitialId = appData?.value(forKey: "AdMobInterstitialUnitId") as? String {
                self.interstitial = GADInterstitial(adUnitID: interstitialId)
                self.interstitial.delegate = self
                self.interstitial.load(self.request)
            }
            self.count = self.showInterstitialInSecoundsEvery
        }
    }
    
    func counterForInterstitialAd() {
        if(self.interstitialShownForFirstTime == true && self.count > 0) {
            self.count = self.count - 1
            print("COUNTER FOR INTERSTITIAL AD: \(self.count)")
        } else {
            self.count = self.showInterstitialInSecoundsEvery
            self.showInterstitialAd()
        }
    }
    
    func showInterstitialAd() {
        if self.interstitialShownForFirstTime == true && self.count == self.showInterstitialInSecoundsEvery {
            if self.interstitial != nil && self.interstitial.isReady {
                self.interstitial.present(fromRootViewController: self)
                self.interstitialShownForFirstTime = true
            } else {
                self.loadBannerAd()
            }
        }
    }
    
    func interstitialDidDismissScreen(_ ad: GADInterstitial!) {
        self.loadBannerAd()
        self.loadInterstitalAd()
    }
    
    func adViewDidReceiveAd(_ bannerView: GADBannerView!) {

    }
    
    func adView(_ bannerView: GADBannerView!, didFailToReceiveAdWithError error: GADRequestError!) {
        print("adView:didFailToReceiveAdWithError: \(error.localizedDescription)")
    }
    
    func loadBannerAd(){
        if Defaults[.adsPurchased] == false {
            let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
            if let bannerId = appData?.value(forKey: "AdMobBannerUnitId") as? String {
                let bounds = UIScreen.main.bounds
                
                var y:CGFloat = bounds.height - 50
                if self.toolbar != nil {
                    y = y - self.toolbar!.frame.height
                }
                
                self.bannerView = GADBannerView(frame: CGRect(x: (bounds.width - 320) / 2, y: y, width: 320, height: 50))
                self.bannerView?.adUnitID = bannerId
                self.bannerView?.rootViewController = self
                self.bannerView?.load(self.request)
                self.bannerView?.delegate = self
            } else {
                self.bannerView?.removeFromSuperview()
                self.wkWebView?.frame = self.getFrame()
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        self.backgroundImage?.removeFromSuperview()
        
        UIView.transition(with: self.view, duration: 0.1, options: .transitionCrossDissolve, animations: {
            
            let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
            if let urlString = appData?.value(forKey: "URL") as? String {
                if self.mainURL != URL(string: urlString) {
                    self.mainURL = URL(string: urlString)
                }
            }
            
            UserDefaults.standard.removeObject(forKey: "URL")
            
            if self.popViewController == nil {
                if self.wkWebView != nil {
                    self.view.addSubview(self.wkWebView!)
                    self.interstitialShownForFirstTime = true
                }
                
                if self.toolbar != nil {
                    self.view.addSubview(self.toolbar!)
                }
                
                if self.bannerView != nil {
                    self.view.addSubview(self.bannerView!)
                }
                
                self.showInterstitialAd()

            }
            
        }) { (success) in
            self.load.hide(animated: true)
        }
    }
    
    func getViewController(_ configuration:WKWebViewConfiguration) -> UIViewController {
        let webView:WKWebView = WKWebView(frame: self.view.frame, configuration: configuration)
        webView.frame = UIScreen.main.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        let newViewController = UIViewController()
        newViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(ViewController.dismissViewController))
        newViewController.modalPresentationStyle = .overCurrentContext
        newViewController.view = webView
        return newViewController
    }
    
    func dismissPopViewController(_ domain:String) {
//        let mainDomain = self.getDomainFromURL(self.mainURL!)
//        if domain == mainDomain{
//            if self.popViewController != nil {
//                self.dismissViewController()
//            }
//        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        self.popViewController = self.getViewController(configuration)
        let navController = UINavigationController(rootViewController: self.popViewController!)
        self.present(navController, animated: true, completion: nil)
        return self.popViewController?.view as? WKWebView
    }
    
    func dismissViewController() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func userContentController(_ userContentController:WKUserContentController, message:WKScriptMessage) {
        print(message)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {

    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // You can inject java script here if required as below
//        let javascript = "var meta = document.createElement('meta');meta.setAttribute('name', 'viewport');meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');document.getElementsByTagName('head')[0].appendChild(meta);";
//        self.wkWebView.evaluateJavaScript(javascript, completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
        if let backupURL = appData?.value(forKey: "BackupURL") as? String {
            let request = URLRequest(url: URL(string: backupURL)!)
            _ = self.wkWebView?.load(request)
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        let domain = self.getDomainFromURL(webView.url)
        self.dismissPopViewController(domain)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("NAVIGATION URL: \(navigationAction.request.url!.host)")
        
        let url = navigationAction.request.url?.absoluteString
        
        let hostAddress = navigationAction.request.url?.host
        
        // To connnect app store
        if hostAddress == "itunes.apple.com" {
            if UIApplication.shared.canOpenURL(navigationAction.request.url!) {
                UIApplication.shared.openURL(navigationAction.request.url!)
                decisionHandler(.cancel)
                return
            }
        }
        
        
        #if DEBUG
            print("url = \(url), host = \(hostAddress)")
        #endif
        
        let url_elements = url!.components(separatedBy: ":")
        
        switch url_elements[0] {
        case "tel":
            #if DEBUG
                print("this is phone number")
            #endif
            openCustomApp(urlScheme: "telprompt://", additional_info: url_elements[1])
            decisionHandler(.cancel)
            
        case "sms":
            #if DEBUG
                print("this is sms")
            #endif
            openCustomApp(urlScheme: "sms://", additional_info: url_elements[1])
            decisionHandler(.cancel)
            
        case "mailto":
            #if DEBUG
                print("this is mail")
            #endif
            openCustomApp(urlScheme: "mailto://", additional_info: url_elements[1])
            decisionHandler(.cancel)
            
        case "comgooglemaps":
            #if DEBUG
                print("this is sms")
            #endif
            openCustomApp(urlScheme: "comgooglemaps://", additional_info: url_elements[1])
            decisionHandler(.cancel)
        default:
            #if DEBUG
                print("normal http request")
            #endif
        }

        let domain = self.getDomainFromURL(navigationAction.request.url!)
        
        if (navigationAction.navigationType == WKNavigationType.linkActivated) {
            print("domains: \(domain)")
            print("navigationType: LinkActivated")
            
            self.dismissPopViewController(domain)
            decisionHandler(WKNavigationActionPolicy.allow)
        } else if (navigationAction.navigationType == WKNavigationType.backForward) {
            print("navigationType: BackForward")
            decisionHandler(WKNavigationActionPolicy.allow)
        } else if (navigationAction.navigationType == WKNavigationType.formResubmitted) {
            print("navigationType: FormResubmitted")
            decisionHandler(WKNavigationActionPolicy.allow)
        } else if (navigationAction.navigationType == WKNavigationType.formSubmitted) {
            print("navigationType: FormSubmitted")
            self.dismissPopViewController(domain)
            decisionHandler(WKNavigationActionPolicy.allow)
        } else if (navigationAction.navigationType == WKNavigationType.reload) {
            print("navigationType: Reload")
            decisionHandler(WKNavigationActionPolicy.allow)
        } else {
            self.dismissPopViewController(domain)
            decisionHandler(WKNavigationActionPolicy.allow)
        }
    }
    
    /**
     open custom app with urlScheme : telprompt, sms, mailto
     
     - parameter urlScheme: telpromt, sms, mailto
     - parameter additional_info: additional info related to urlScheme
     */
    func openCustomApp(urlScheme:String, additional_info:String){
        let url = "\(urlScheme)"+"\(additional_info)"
        if let requestUrl:NSURL = NSURL(string:url) {
            let application:UIApplication = UIApplication.shared
            if application.canOpenURL(requestUrl as URL) {
                application.openURL(requestUrl as URL)
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow);
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        UIView.transition(with: self.view, duration: 0.1, options: .transitionCrossDissolve, animations: {
            for view in self.view.subviews {
                if view is GADBannerView {
                    view.removeFromSuperview()
                }
            }
            self.bannerView = nil
            self.loadBannerAd()
        }) { (success) in
            
        }
    }
    
    override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        UIView.transition(with: self.view, duration: 0.1, options: .transitionCrossDissolve, animations: {
            let bounds = UIScreen.main.bounds
            self.toolbar?.frame = CGRect(x: 0, y: bounds.height - 40, width: bounds.width, height: 40)
            
            var y:CGFloat = bounds.height - 50
            if self.toolbar != nil {
                y = y - self.toolbar!.frame.height
            }
            
            if self.bannerView != nil {
                self.view.addSubview(self.bannerView!)
            }
            self.bannerView?.frame = CGRect(x: (bounds.width - 320) / 2, y: y, width: 320, height: 50)
            self.wkWebView?.frame = self.getFrame()
        }) { (success) in

        }
    }
    
    func getFrame() -> CGRect {
        let bounds = UIScreen.main.bounds
        
        var height:CGFloat = bounds.height
        if self.bannerView != nil {
            height = height - self.bannerView!.frame.height
        }
        
        if self.toolbar != nil {
            height = height - self.toolbar!.frame.height
        }

        return  CGRect(x: 0, y: 0, width: bounds.width, height: height)
    }
    
    func getToolbar() -> UIToolbar? {
        var toolbar: UIToolbar?
        let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
        if appData?.value(forKey: "Toolbar") as? Bool == true {
            self.backButton = UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: self, action: #selector(ViewController.back))
            self.forwardButton = UIBarButtonItem(image: UIImage(named: "forward"), style: .plain, target: self, action: #selector(ViewController.forward))
            self.reloadButton = UIBarButtonItem(image: UIImage(named: "refresh"), style: .plain, target: self, action: #selector(ViewController.reload))
            self.iapButton = UIBarButtonItem(image: UIImage(named: "block-ad"), style: .plain, target: self, action: #selector(ViewController.removeAdsAction))

            self.backButton?.tintColor = UIColor(hexString: "0e8494")
            self.forwardButton?.tintColor = UIColor(hexString: "0e8494")
            self.reloadButton?.tintColor = UIColor(hexString: "0e8494")
            self.iapButton?.tintColor = UIColor(hexString: "0e8494")

            let fixedSpaceButton = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: self, action: nil)
            fixedSpaceButton.width = 42
            let flexibleSpaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
            
            var items = [UIBarButtonItem]()
            items.append(self.backButton!)
            items.append(fixedSpaceButton)
            items.append(self.forwardButton!)
            
            if Defaults[.adsPurchased] == false {
                items.append(flexibleSpaceButton)
                items.append(self.iapButton!)
            }
            
            items.append(flexibleSpaceButton)
            items.append(self.reloadButton!)
            
            let bounds = UIScreen.main.bounds
            toolbar = UIToolbar(frame: CGRect(x: 0, y: bounds.height - 40, width: bounds.width, height: 40))
            toolbar!.setItems(items, animated: true)
        }
        return toolbar
    }
    
    func removeAdsAction() {
        let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
        if let productId = appData?.value(forKey: "RemoveAdsPurchaseId") as? String {
            SwiftyStoreKit.retrieveProductsInfo([productId]) { result in
                if let product = result.retrievedProducts.first {
                    let numberFormatter = NumberFormatter()
                    numberFormatter.locale = product.priceLocale
                    numberFormatter.numberStyle = .currency
                    let priceString = numberFormatter.string(from: product.price)
                    print("Product: \(product.localizedDescription), price: \(priceString)")
                    
                    let alert = UIAlertController(title: "In-App Purchase", message: "Do you want to purchase \(product.localizedTitle) for \(priceString!)", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action: UIAlertAction!) in
                        
                    }))
                    alert.addAction(UIAlertAction(title: "Buy", style: .default, handler: { (action: UIAlertAction!) in
                        self.purchase()
                    }))
                    self.present(alert, animated: true, completion: nil)
                    
                } else {
                    print("Error: \(result.error)")
                    
                    let alert = UIAlertController(title: "In-App Purchase", message: "Product not found", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction!) in
                        
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func purchase() {
        let appData = NSDictionary(contentsOfFile: AppDelegate.dataPath())
        if let productId = appData?.value(forKey: "RemoveAdsPurchaseId") as? String {
            SwiftyStoreKit.purchaseProduct(productId) { result in
                switch result {
                case .success(let productId):
                    print("Purchase Success: \(productId)")
                    
                    Defaults[.adsPurchased] = true
                    self.timer.invalidate()
                    self.timer = nil
                    
                    let alert = UIAlertController(title: "In-App Purchase", message: "Purchase successful!", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction!) in
                        
                        Defaults[.adsPurchased] = true
                        self.timer.invalidate()
                        self.timer = nil
                        
                        for view in self.view.subviews {
                            if view is GADBannerView {
                                view.removeFromSuperview()
                            }
                        }
                        self.bannerView = nil

                        self.loadBannerAd()
                        
                    }))
                    self.present(alert, animated: true, completion: nil)
                    
                case .error(let error):
                    print("Purchase Failed: \(error)")
                    
                    let alert = UIAlertController(title: "In-App Purchase", message: "Purchase Failed", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction!) in
                        
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func getDomainFromURL(_ url:URL?) -> String {
        var domain:String = ""
        let domains = self.domains()
        if url?.host != nil {
            let host = url!.host?.lowercased()
            var separatedHost = host?.components(separatedBy: ".")
            separatedHost = separatedHost?.reversed()
            
            for tld in separatedHost! {
                if domains.contains(tld.uppercased()) {
                    domain = ".\(tld)\(domain)"
                } else {
                    domain = "\(tld)\(domain)"
                    break
                }
            }
        }
        return domain
    }
    
    func domains() -> NSArray {
        if let url = Bundle.main.url(forResource: "domains", withExtension: "json") {
            if let data = try? Data(contentsOf: url) {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    if let domains = json as? [String] {
                        return domains as NSArray
                    }
                } catch {
                    print("error serializing JSON: \(error)")
                }
            }
            print("Error!! Unable to load domains.json.json")
        }
        return []
    }
    
    //Commented:    black status bar.
    //Uncommented:  white status bar.
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
}

