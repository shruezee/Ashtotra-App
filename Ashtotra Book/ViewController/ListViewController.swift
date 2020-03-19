//
//  ViewController.swift
//  Ashtotra Book
//
//  Created by shruthi palchandar on 16/7/19.
//  Copyright © 2019 Shruezee. All rights reserved.
//

import UIKit
import GoogleMobileAds

let defaultString = "default"

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var tableData = [String]()
    @IBOutlet weak var tableAstotras: UITableView!
    @IBOutlet weak var bannerView: GADBannerView!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableData = Ashtotras().getDocuments()
        self.tableAstotras.reloadData()

        self.tableAstotras.tableFooterView = UIView()
        
        self.navigationController?.navigationBar.barTintColor = UIColor.red
        
        #if DEBUG
        bannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        #else
        bannerView.adUnitID = "ca-app-pub-7905807029216523/7134907960"
        #endif

        bannerView.rootViewController = self
        bannerView.delegate = self
        
        bannerView.load(GADRequest())

    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ListCell") as? ListCell else { print ("here")
            return UITableViewCell() }
        
        var astotraName = "\(tableData[indexPath.row])"
        
        var imageName = astotraName.components(separatedBy: "_").first ?? defaultString
        imageName = imageName.lowercased()
        imageName = "\(imageName)big"
        if let img = UIImage(named: imageName) {
            cell.imgeView?.image = img
        } else {
            cell.imgeView?.image = UIImage(named: defaultString)
        }
        
        astotraName = astotraName.replacingOccurrences(of: PDFPathSeperator, with: " ", options: .literal, range: nil)
        astotraName = astotraName.replacingOccurrences(of: DotFormat, with: "", options: .literal, range: nil)
        astotraName = astotraName.replacingOccurrences(of: Language1, with: "", options: .literal, range: nil)
        astotraName = astotraName.replacingOccurrences(of: PDFPathSting1, with: "", options: .literal, range: nil)
        astotraName = astotraName.replacingOccurrences(of: PDFPathString2, with: "", options: .literal, range: nil)
        
        cell.labelAstotraName?.text = astotraName
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedStotra = tableData[indexPath.row]
        DisplayViewController.fileName = selectedStotra
    }
    
    func addBannerViewToView(_ bannerView: GADBannerView) {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)
        view.addConstraints(
            [NSLayoutConstraint(item: bannerView,
                                attribute: .bottom,
                                relatedBy: .equal,
                                toItem: view.safeAreaLayoutGuide.bottomAnchor,//bottomLayoutGuide.topAnchor,
                                attribute: .top,
                                multiplier: 1,
                                constant: 0),
             NSLayoutConstraint(item: bannerView,
                                attribute: .centerX,
                                relatedBy: .equal,
                                toItem: view,
                                attribute: .centerX,
                                multiplier: 1,
                                constant: 0)
            ])
    }
}

extension ListViewController:GADBannerViewDelegate {
    
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("ad received")
    }
    
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        print("error in ad", error)
    }
}
