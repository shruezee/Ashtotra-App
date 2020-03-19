//
//  ListCell.swift
//  Ashtotra Book
//
//  Created by shruthi palchandar on 16/7/19.
//  Copyright © 2019 Shruezee. All rights reserved.
//

import UIKit

class ListCell: UITableViewCell {
    
    @IBOutlet weak var labelAstotraName: UILabel!
    @IBOutlet weak var imgeView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
