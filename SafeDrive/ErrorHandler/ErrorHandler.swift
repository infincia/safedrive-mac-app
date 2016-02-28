
//  Copyright (c) 2014 Infincia LLC. All rights reserved.
//

import Foundation

func SDLog(line: String, _ arguments: CVarArgType...) -> Void {
    return withVaList(arguments) { SDLogv(line, $0) }
}