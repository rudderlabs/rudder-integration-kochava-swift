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
        if !kochavaConfig.appGUID.isEmpty {
            if kochavaConfig.appTrackingTransparency {
                KVATracker.shared.appTrackingTransparency.enabledBool = kochavaConfig.appTrackingTransparency
            }
            if kochavaConfig.skAdNetwork {
                KVAAdNetworkProduct.shared.register()
            }
            KVATracker.shared.start(withAppGUIDString: kochavaConfig.appGUID)
            KVALog.shared.level = getLogLevel(rsLogLevel: client?.configuration?.logLevel ?? .none)
            client?.log(message: "Initializing Kochava SDK", logLevel: .debug)
        }
    }
    
    func track(message: TrackMessage) -> TrackMessage? {
        var kochavaEvent: KVAEvent?
        /// For E-Commerce event mapping visit: https://support.kochava.com/reference-information/post-install-event-examples/
        if let eventType = getKochavaECommerceEventType(from: message.event) {
            kochavaEvent = KVAEvent.init(type: eventType)
            if let properties = message.properties {
                switch eventType {
                case KVAEventType.purchase:
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
                    insertProductProperties(params: &kochavaEvent, properties: properties)
                    if let quantity = properties[RSKeys.Ecommerce.quantity] as? NSNumber {
                        kochavaEvent?.quantityDoubleNumber = quantity
                    }
                case KVAEventType.addToWishList, KVAEventType.view:
                    insertProductProperties(params: &kochavaEvent, properties: properties)
                case KVAEventType.checkoutStart:
                    insertECommerceProductData(params: &kochavaEvent, properties: properties)
                    insertCurrency(params: &kochavaEvent, properties: properties)
                case KVAEventType.rating:
                    if let rating = properties[RSKeys.Ecommerce.rating] as? NSNumber {
                        kochavaEvent?.ratingValueDoubleNumber = rating
                    }
                case KVAEventType.search:
                    if let query = properties[RSKeys.Ecommerce.query] as? String {
                        kochavaEvent?.uriString = query
                    }
                default:
                    break
                }
                // Filter ECommerce event property from custom property
                insertCustomPropertiesData(event: &kochavaEvent, properties: properties)
            }
        }
        // Custom event
        else {
            kochavaEvent = KVAEvent(customWithNameString: message.event)
            // Custom properties
            if let properties = message.properties {
                kochavaEvent?.infoDictionary = properties
            }
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
                KVAEvent.sendCustom(withNameString: "screen view \(message.name)", infoDictionary: properties)
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
        return [RSKeys.Ecommerce.products, RSKeys.Ecommerce.productName, RSKeys.Ecommerce.productId, RSKeys.Ecommerce.currency, RSKeys.Ecommerce.revenue, RSKeys.Ecommerce.value, RSKeys.Ecommerce.total, RSKeys.Ecommerce.quantity, RSKeys.Ecommerce.query]
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
    
    // This method will filter out ECommerce event property
    func insertCustomPropertiesData(event: inout KVAEvent?, properties: [String: Any]) {
        var params = [String: Any]()
        for (key, value) in properties {
            if TRACK_RESERVED_KEYWORDS.contains(key) {
                continue
            }
            params[key] = value
        }
        if !params.isEmpty {
            event?.infoDictionary = params
        }
    }
}

struct RudderKochavaConfig: Codable {
    private let _appGUID: String?
    var appGUID: String {
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
