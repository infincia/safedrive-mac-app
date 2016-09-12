
//  Copyright (c) 2014-2016 SafeDrive. All rights reserved.
//

import Foundation

func SDLog(_ line: String, _ arguments: CVarArg...) -> Void {
    return withVaList(arguments) { SDLogv(line, $0) }
}
