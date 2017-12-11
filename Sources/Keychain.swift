//
//  Keychain.swift
//
//  Copyright (c) 2017 Todd Kramer (http://www.tekramer.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Security

public final class Keychain {

    private enum Constants {
        static let accessible = kSecAttrAccessible.stringValue
        static let accessGroup = kSecAttrAccessGroup.stringValue
        static let account = kSecAttrAccount.stringValue
        static let `class` = kSecClass.stringValue
        static let matchLimit = kSecMatchLimit.stringValue
        static let returnData = kSecReturnData.stringValue
        static let service = kSecAttrService.stringValue
        static let valueData = kSecValueData.stringValue

        static let genericPassword = kSecClassGenericPassword.stringValue
        static let matchLimitOne = kSecMatchLimitOne.stringValue
    }

    public static let defaultService: String = Bundle.main.infoDictionary?[kCFBundleIdentifierKey.stringValue] as? String
        ?? "com.codablekeychain.service"

    public static let `default` = Keychain()

    let securityItemManager: SecurityItemManaging

    init(securityItemManager: SecurityItemManaging = SecurityItemManager.default) {
        self.securityItemManager = securityItemManager
    }

    // MARK: - Public

    public func store<T: KeychainStorable>(_ storable: T) throws {
        let newData = try JSONEncoder().encode(storable)
        var query = self.query(for: storable, isRetrieving: false)
        let existingData = try data(with: storable.keychainAttributes)
        var status = noErr
        let newAttributes: [String: Any] = [Constants.valueData: newData, Constants.accessible: storable.accessible.rawValue]
        if existingData != nil {
            status = securityItemManager.update(withQuery: query, attributesToUpdate: newAttributes)
        } else {
            query.merge(newAttributes) { $1 }
            status = securityItemManager.add(withAttributes: query, result: nil)
        }
        if let error = error(fromStatus: status) {
            throw error
        }
    }

    public func retrieveValue<T: KeychainStorable>(with attributes: KeychainAttributes) throws -> T? {
        guard let data = try data(with: attributes) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func delete<T: KeychainStorable>(_ storable: T) throws {
        let query = self.query(with: storable.keychainAttributes, isRetrieving: false)
        let status = securityItemManager.delete(withQuery: query)
        if let error = error(fromStatus: status) { throw error }
    }

    // MARK: - Query

    func query(with attributes: KeychainAttributes, isRetrieving: Bool) -> [String: Any] {
        var query: [String: Any] = [
            Constants.service: attributes.service,
            Constants.class: Constants.genericPassword,
            Constants.account: attributes.account
        ]
        if let accessGroup = attributes.accessGroup {
            query[Constants.accessGroup] = accessGroup
        }
        if isRetrieving {
            query[Constants.matchLimit] = Constants.matchLimitOne
            query[Constants.returnData] = kCFBooleanTrue
        }
        return query
    }

    func query(for storable: KeychainStorable, isRetrieving: Bool) -> [String: Any] {
        var query = self.query(with: storable.keychainAttributes, isRetrieving: isRetrieving)
        query[Constants.accessible] = storable.accessible.rawValue
        return query
    }

    func data(with attributes: KeychainAttributes) throws -> Data? {
        let query = self.query(with: attributes, isRetrieving: true)
        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            securityItemManager.copyMatching(query, result: UnsafeMutablePointer($0))
        }
        if let error = error(fromStatus: status), error != .itemNotFound { throw error }
        return result as? Data
    }

    func error(fromStatus status: OSStatus) -> KeychainError? {
        guard status != noErr && status != errSecSuccess else { return nil }
        return KeychainError(rawValue: Int(status)) ?? .unknown
    }

}
