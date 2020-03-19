//
//  Utils.swift
//  Ashtotra Book
//
//  Created by shruthi palchandar on 16/7/19.
//  Copyright © 2019 Shruezee. All rights reserved.
//

import UIKit

// MARK: - ShowLoader
// ------------------
func showLoader(view: UIView) -> UIActivityIndicatorView {
    let spinner = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height:40))
    spinner.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    spinner.layer.cornerRadius = 3.0
    spinner.clipsToBounds = true
    spinner.hidesWhenStopped = true
    spinner.style = UIActivityIndicatorView.Style.white
    spinner.center = view.center
    view.addSubview(spinner)
    spinner.startAnimating()
    UIApplication.shared.beginIgnoringInteractionEvents()
    return spinner
}

extension UIActivityIndicatorView {
    // MARK: - DismissLoader
    // ------------------
    func dismissLoader() {
        DispatchQueue.main.async {
            self.stopAnimating()
            UIApplication.shared.endIgnoringInteractionEvents()
        }
    }
}

//MARK:- Setting Theme
//--------------------
struct Theme {
    static var isDark:Bool = false
    
    static func setLight(_ forView:UIView) {
        isDark = false
        forView.backgroundColor = UIColor.white
        for subView in forView.subviews {
            if let _ = subView as? UILabel{
                (subView as! UILabel).textColor = UIColor.darkText
            }
        }
        
    }
    static func setDark(_ forView:UIView) {
        isDark = true
        forView.backgroundColor = UIColor.darkGray
        for subView in forView.subviews {
            if let _ = subView as? UILabel {
                (subView as! UILabel).textColor = UIColor.lightText
            }
        }
    }
}
