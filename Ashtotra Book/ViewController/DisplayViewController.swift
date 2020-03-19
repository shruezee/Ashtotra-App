//
//  DisplayViewController.swift
//  Ashtotra Book
//
//  Created by shruthi palchandar on 16/7/19.
//  Copyright © 2019 Shruezee. All rights reserved.
//

import UIKit
import PDFKit

class DisplayViewController: UIViewController {
    
    static var fileName = ""
    var selectedLanName = ""
    var currentFileName = ""
    var spinner:UIActivityIndicatorView? = nil
    
    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet var pdfView: PDFView!
    @IBOutlet var imageView: UIImageView!


    @IBAction func valueChanged(_ sender: UISegmentedControl) {
        loadPDF(withIndex:sender.selectedSegmentIndex)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        spinner = showLoader(view: self.view)
        
        self.navigationController?.navigationBar.barTintColor = UIColor.red
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setPDFView()
        currentFileName = DisplayViewController.fileName
        loadPDF(withIndex: 0)
        spinner?.dismissLoader()
        setBG()
    }
    
    func setBG() {
        let astotraName = DisplayViewController.fileName
        var imageName = astotraName.components(separatedBy: PDFPathSeperator).first ?? defaultString
        imageName = imageName.lowercased()
        if let img = UIImage(named: "\(imageName)big") {
          imageView.image = img
          imageView.sizeToFit()
        }
    }
    
    func setPDFView() {
        // Add PDFView to view controller.
        pdfView = PDFView(frame: pdfView.bounds)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let segmentFrame = segmentedControl.frame
      
        pdfView.frame.origin.y = segmentFrame.origin.y + segmentFrame.size.height + imageView.frame.origin.y + imageView.frame.size.height
       
        pdfView.frame.size.height = self.view.frame.height - (segmentFrame.origin.y + segmentFrame.size.height + imageView.frame.origin.y + imageView.frame.size.height)
        pdfView.frame.origin.x = 20
        // If View exist
        for view in self.view.subviews {
            if let subview = view as? PDFView {
                subview.removeFromSuperview()
                break
            }
        }
        pdfView.backgroundColor = UIColor.white
        self.view.addSubview(pdfView)
        
        // Fit content in PDFView.
        pdfView.autoScales = true
    }
    
    
    func loadPDF(withIndex:Int) {
      let path = Ashtotras().getPDFURL(forLanguageOption: withIndex, currentFileName: &currentFileName, selectedLanName: &selectedLanName)
        
        if let document = PDFDocument(url: path) {
            pdfView.document = document
            pdfView.documentView?.backgroundColor = UIColor.white
            pdfView.subviews[0].backgroundColor = UIColor.white
            
        }
    }
    
}
