//
//  Ashtotra.swift
//  Ashtotra
//
//  Created by shruthi palchandar on 4/3/20.
//  Copyright © 2020 Shruezee. All rights reserved.
//

import Foundation

///PlainEnglish
let Language1 = "PlainEnglish"
///Kannada
let Language2 = "Kannada"
///Devanagari
let Language3 = "Devanagari"
///Telugu
let Language4 = "Telugu"
///Tamil
let Language5 = "Tamil"
///Gujarati
let Language6 = "Gujarati"
///English
let LanguageDefault = "English"

let Format = "pdf"
let DotFormat = ".pdf"
let PDFPathSting1 = "Sata"
let PDFPathString2 = "Namavali"
let PDFPathSeperator = "_"

struct Ashtotras {
  
  public func getDocuments() -> [String] {
    var deityNames = [String]()
    
    let fileManager = FileManager.default
    let path = Bundle.main.resourcePath!
    do {
      let items = try fileManager.contentsOfDirectory(atPath: path)
      
      for item in items {
        if item.contains(Format) && item.contains(Language1) {
          var name = item
          name = name.replacingOccurrences(of: DotFormat, with: "", options: .literal, range: nil)
          deityNames.append(name)
        }
      }
      
    } catch {
      print("Failed to read directory")
    }
    return deityNames
  }
  
  public func getPDFURL(forLanguageOption:Int, currentFileName: inout String, selectedLanName:inout String) -> URL {
        switch forLanguageOption {
        case 0:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: Language1, options: .literal, range: nil)
            selectedLanName = Language1
            break
        case 1:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: Language2, options: .literal, range: nil)
            selectedLanName = Language2
            break
        case 2:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: Language3, options: .literal, range: nil)
            selectedLanName = Language3
            break
        case 3:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: Language4, options: .literal, range: nil)
            selectedLanName = Language4
            break
        case 4:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: Language5, options: .literal, range: nil)
            selectedLanName = Language5
            break
        case 5:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: Language6, options: .literal, range: nil)
            selectedLanName = Language6
            break
            
        default:
            currentFileName = currentFileName.replacingOccurrences(of: selectedLanName, with: LanguageDefault, options: .literal, range: nil)
            selectedLanName = LanguageDefault
        }
        
        // Load Sample.pdf file from app bundle.
        guard let path = Bundle.main.url(forResource: currentFileName, withExtension: "pdf") else {
            print("PDF error")
            return URL(fileURLWithPath: "")
        }
     return path
  }
  
}

