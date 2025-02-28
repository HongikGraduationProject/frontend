//
//  Spacer.swift
//  DSKit
//
//  Created by choijunios on 8/22/24.
//

import UIKit

public class Spacer: UIView {
    
    let width: CGFloat?
    let height: CGFloat?
    
    public override var intrinsicContentSize: CGSize {
        .init(
            width: width ?? super.intrinsicContentSize.width,
            height: height ?? super.intrinsicContentSize.height
        )
    }
    
    public init(width: CGFloat? = nil, height: CGFloat? = nil, color: UIColor = .clear) {
        self.width = width
        self.height = height
        super.init(frame: .zero)
        self.backgroundColor = color
    }
    required init?(coder: NSCoder) { fatalError() }
}
