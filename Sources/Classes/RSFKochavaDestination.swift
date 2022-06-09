//
//  RSKochavaDestination.swift
//  RudderKochava
//
//  Created by Pallab Maiti on 21/03/22.
//

import Foundation
import Rudder
import KochavaTracker
import KochavaAdNetwork

class RSKochavaDestination: RSDestinationPlugin {
    let type = PluginType.destination
    let key = "Kochava"
    var client: RSClient?
    var controller = RSController()
    
    func update(serverConfig: RSServerConfig, type: UpdateType) {
        guard type == .initial else { return }
        guard let kochavaConfig: RudderKochavaConfig = serverConfig.getConfig(forPlugin: self) else {
            client?.log(message: "Failed to Initialize Kochava Factory", logLevel: .warning)
            return
        }
        if let destination = serverConfig.getDestination(by: key), let config = destination.config?.dictionaryValue {
            if let appGUID = config["apiKey"] as? String {
                if let appTrackingTransparency = config["appTrackingTransparency"] as? Bool {
                    KVATracker.shared.appTrackingTransparency.enabledBool = appTrackingTransparency
                }
                if let skAdNetwork = config["skAdNetwork"] as? Bool, skAdNetwork {
                    KVAAdNetworkProduct.shared.register()
                }
                KVATracker.shared.start(withAppGUIDString: appGUID)
                KVALog.shared.level = getLogLevel(rsLogLevel: client?.configuration?.logLevel ?? .none)
            }
        }
    }
    
    func track(message: TrackMessage) -> TrackMessage? {
        var kochavaEvent: KVAEvent?
        if let eventType = getKochavaECommerceEventType(from: message.event) {
            kochavaEvent = KVAEvent.init(type: eventType)
            if let properties = message.properties {
                switch eventType {
                case KVAEventType.purchase:
                    // userId, Name, ContentId, Price, currency, Checkout as Guest
                    insertECommerceProductData(params: &kochavaEvent, properties: properties)
                    insertCurrency(params: &kochavaEvent, properties: properties)
                    if let revenue = properties[RSKeys.Ecommerce.revenue] {
                        kochavaEvent?.priceDoubleNumber = Double("\(revenue)") as NSNumber?
                    } else if let value = properties[RSKeys.Ecommerce.value] {
                        kochavaEvent?.priceDoubleNumber = Double("\(value)") as NSNumber?
                    } else if let total = properties[RSKeys.Ecommerce.total] {
                        kochavaEvent?.priceDoubleNumber = Double("\(total)") as NSNumber?
                    }
                case KVAEventType.addToCart:
                    // userId, Name, ContentId, Item Quantity
                    insertProductProperties(params: &kochavaEvent, properties: properties)
                    if let quantity = properties[RSKeys.Ecommerce.quantity] as? NSNumber {
                        kochavaEvent?.quantityDoubleNumber = quantity
                    }
                case KVAEventType.addToWishList:
                    // UserId, Name, ContentId, Referral From
                    insertProductProperties(params: &kochavaEvent, properties: properties)
                case KVAEventType.checkoutStart:
                    // userId, Name, ContentId, Checkout as Guest, Currency
                    insertECommerceProductData(params: &kochavaEvent, properties: properties)
                    insertCurrency(params: &kochavaEvent, properties: properties)
                case KVAEventType.rating:
                    // Rating Value, Maximum Rating
                    if let rating = properties[RSKeys.Ecommerce.rating] as? NSNumber {
                        kochavaEvent?.ratingValueDoubleNumber = rating
                    }
                case KVAEventType.search:
                    // uri, result
                    if let query = properties[RSKeys.Ecommerce.query] as? String {
                        kochavaEvent?.uriString = query
                    }
                case KVAEventType.view:
                    // userId, name, contentId, referral form
                    insertProductProperties(params: &kochavaEvent, properties: properties)
                default:
                    break
                }
            }
        } else {
            kochavaEvent = KVAEvent(customWithNameString: message.event)
        }
        if let properties = message.properties {//}, let params = getCustomPropertiesData(properties: properties) {
            kochavaEvent?.infoDictionary = properties
        }
        if let userId = message.userId, !userId.isEmpty {
            kochavaEvent?.userIdString = userId
        }
        kochavaEvent?.send()
        
        return message
    }
    
    func screen(message: ScreenMessage) -> ScreenMessage? {
        if !message.name.isEmpty {
            if let properties = message.properties {
                KVAEvent.sendCustom(withNameString: "screen view \(message.name)", infoDictionary: properties) //getCustomPropertiesData(properties: properties))
            } else {
                KVAEvent.sendCustom(withNameString: "screen view \(message.name)")
            }
        }
        return message
    }
    
    func reset() {
        KVATracker.shared.invalidate()
    }
}

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

extension RSKochavaDestination: RSPushNotifications {
    func registeredForRemoteNotifications(deviceToken: Data) {
        KVAPushNotificationsToken.register(withData: deviceToken)
    }
    
    func receivedRemoteNotification(userInfo: [AnyHashable : Any]) {
        let event = KVAEvent(type: .pushOpened)
        event.payloadDictionary = userInfo
        event.send()
    }
}

#endif

#if os(watchOS)

import WatchKit

extension RSKochavaDestination: RSPushNotifications {
    func registeredForRemoteNotifications(deviceToken: Data) {
        KVAPushNotificationsToken.register(withData: deviceToken)
    }
    
    func receivedRemoteNotification(userInfo: [AnyHashable: Any]) {
        let event = KVAEvent(type: .pushOpened)
        event.payloadDictionary = userInfo
        event.send()
    }
}

#endif


// MARK: - Support methods

extension RSKochavaDestination {
    var TRACK_RESERVED_KEYWORDS: [String] {
        return ["product_id", "name", "currency", "quantity", "value", "revenue", "total", "query", "products"]
    }
    
    func getKochavaECommerceEventType(from rudderEvent: String) -> KVAEventType? {
        switch rudderEvent {
        case RSEvents.Ecommerce.productAdded: return KVAEventType.addToCart
        case RSEvents.Ecommerce.productAddedToWishList: return KVAEventType.addToWishList
        case RSEvents.Ecommerce.checkoutStarted: return KVAEventType.checkoutStart
        case RSEvents.Ecommerce.orderCompleted: return KVAEventType.purchase
        case RSEvents.Ecommerce.productsSearched: return KVAEventType.search
        case RSEvents.Ecommerce.productReviewed: return KVAEventType.rating
        case RSEvents.Ecommerce.productViewed: return KVAEventType.view
        default: return nil
        }
    }
    
    func getLogLevel(rsLogLevel: RSLogLevel) -> KVALogLevel {
        switch rsLogLevel {
        case .verbose:
            return .trace
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .warn
        case .error:
            return .error
        case .none:
            return .never
        }
    }
    
    /// Set `productId` and `productName` present at the root of the properties
    func insertProductProperties(params: inout KVAEvent?, properties: [String: Any]) {
        if let name = properties[RSKeys.Ecommerce.productName] as? String {
            params?.nameString = name
        }
        if let productId = properties[RSKeys.Ecommerce.productId] as? String{
            params?.contentIdString = productId
        }
    }
    
    func insertCurrency(params: inout KVAEvent?, properties: [String: Any]) {
        if let currency = properties[RSKeys.Ecommerce.currency] as? String {
            params?.nameString = currency
        }
    }
    
    /// Set `productId` and `productName` present inside the products array
    func insertECommerceProductData(params: inout KVAEvent?, properties: [String: Any]) {
        var nameList: [String]?
        var productIdList: [String]?
        
        if let products = properties[RSKeys.Ecommerce.products] as? [[String: Any]] {
            nameList = products.compactMap { dict in
                return dict[RSKeys.Ecommerce.productName] as? String
            }
            productIdList = products.compactMap { dict in
                return dict[RSKeys.Ecommerce.productId] as? String
            }
        
            if let nameList = nameList, let names = getJSONString(list: nameList) {
                params?.nameString = names
            }
            if let productIdList = productIdList, let ids = getJSONString(list: productIdList) {
                params?.contentIdString = ids
            }
        }
    }
    
    func getJSONString(list: [String]) -> String? {
        guard !list.isEmpty else { return nil }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: list ,options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
//    func getCustomPropertiesData(properties: [String: Any]) -> [String: Any]? {
//        if properties.isEmpty {
//            return nil
//        }
//        var params: [String: Any]?
//        for (key, value) in properties {
//            if TRACK_RESERVED_KEYWORDS.contains(key) {
//                continue
//            }
//            switch value {
//            case let v as String:
//                params?[key] = v
//            case let v as Int:
//                params?[key] = Double(v)
//            case let v as Double:
//                params?[key] = v
//            default:
//                params?[key] = "\(value)"
//            }
//        }
//        return params
//    }
}

struct RudderKochavaConfig: Codable {
    private let _appGUID: String?
    var appGuid: String {
        return _appGUID ?? ""
    }
    
    private let _appTrackingTransparency: Bool?
    var appTrackingTransparency: Bool {
        return _appTrackingTransparency ?? false
    }
    
    private let _skAdNetwork: Bool?
    var skAdNetwork: Bool {
        return _skAdNetwork ?? false
    }
    
    enum CodingKeys: String, CodingKey {
        case _appGUID = "apiKey"
        case _appTrackingTransparency = "appTrackingTransparency"
        case _skAdNetwork = "skAdNetwork"
    }
}

@objc
public class RudderKochavaDestination: RudderDestination {
    
    public override init() {
        super.init()
        plugin = RSKochavaDestination()
    }
    
}
