//
//  AshtotrasUnitTest.swift
//  Ashtotra
//
//  Created by shruthi palchandar on 4/3/20.
//  Copyright © 2020 Shruezee. All rights reserved.
//

import XCTest
@testable import Ashtotra

class AshtotrasUnitTest: XCTestCase {
  var ashtoras = [String]()
  
  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    ashtoras = Ashtotras().getDocuments()
    }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    super.tearDown()
    ashtoras = []
  }
  
  func testAshtotrasGetDocumetData() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XCTAssertGreaterThan(ashtoras.count, 0)
    
    XCTAssertEqual(ashtoras.count, 15)
    
    XCTAssertEqual(ashtoras.contains("Ganesha_Ashtottara_Sata_Namavali_PlainEnglish"), true)
  }
  
  func testGetPDFURL() {
   
    var selectedLanguageName = Language1
    var currentFileName = "Durga_Ashtottara_Sata_Namavali_PlainEnglish"
    let selectedLanguageIndex = 0
    
    guard let path = Bundle.main.url(forResource: currentFileName, withExtension: Format) else {
      print("here")
      return
    }
    
    XCTAssertEqual(Ashtotras().getPDFURL(forLanguageOption: selectedLanguageIndex, currentFileName: &currentFileName, selectedLanName: &selectedLanguageName), path)
  }
  
  func testPerformanceExample() {
    // This is an example of a performance test case.
    self.measure {
      // Put the code you want to measure the time of here.
    }
  }
  
}
