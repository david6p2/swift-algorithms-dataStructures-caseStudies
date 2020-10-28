//
//  DCError.swift
//  MeLiCarViewer
//
//  Created by David A Cespedes R on 9/15/20.
//  Copyright © 2020 David A Cespedes R. All rights reserved.
//

import Foundation

struct DCError: Error {
  let type: ErrorType
  let errorInfo: String?
}

enum ErrorType: String {
  case invalidCarModel = "The selected car model is invalid"
  case unableToComplete = "We were unable to complete the task. Please try again."
  case invalidResponse = "The response received was invalid. Please try again."
  case invalidData = "The received data was invalid. Please try again or contact support for help."
  case invalidURL = "The URL used was invalid. Please check it and fix it if necessary."
  case unableToDecode = "We could not read the received data to be shown. Please try again or contact support for help."
}
