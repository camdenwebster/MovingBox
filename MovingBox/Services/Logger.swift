import Foundation
import os.log

/// A centralized logging utility that wraps os_log functionality
class Logger {
    // MARK: - Log Categories
    
    /// Log categories to organize logs by subsystem
    enum Category: String {
        case app = "App"
        case ui = "UI"
        case networking = "Network"
        case database = "Database"
        case subscription = "Subscription"
        case ai = "AI"
        case analytics = "Analytics"
        case security = "Security"
        
        /// Returns a string representation for the subsystem
        var subsystem: String {
            return "com.mothersound.movingbox.\(rawValue.lowercased())"
        }
    }
    
    // MARK: - Log Types
    
    /// Define the different log levels available
    enum LogLevel {
        case debug    // For developer debugging, most verbose
        case info     // General information
        case notice   // Important events, but not errors
        case warning  // Potential issues
        case error    // Recoverable errors
        case fault    // System-level failures or crashes
        
        /// Convert to OSLogType
        var osLogType: OSLogType {
            switch self {
            case .debug:   return .debug
            case .info:    return .info
            case .notice:  return .default
            case .warning: return .info      // os_log doesn't have warning, use info
            case .error:   return .error
            case .fault:   return .fault
            }
        }
        
        /// Emoji prefix for more readable console logs
        var emoji: String {
            switch self {
            case .debug:   return "🔍"
            case .info:    return "📱"
            case .notice:  return "📢"
            case .warning: return "⚠️"
            case .error:   return "❌"
            case .fault:   return "💥"
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log a message with the specified category and level
    static func log(_ message: String, category: Category, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        // In debug builds, print to console with emoji and file information for better readability
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("\(level.emoji) [\(category.rawValue)] \(message) (\(fileName):\(line))")
        #endif
        
        // Always log to os_log system
        let logger = OSLog(subsystem: category.subsystem, category: category.rawValue)
        os_log("%{public}@", log: logger, type: level.osLogType, message)
    }
    
    // MARK: - Convenience Methods
    
    static func debug(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }
    
    static func notice(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .notice, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }
    
    static func fault(_ message: String, category: Category, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .fault, file: file, function: function, line: line)
    }
}