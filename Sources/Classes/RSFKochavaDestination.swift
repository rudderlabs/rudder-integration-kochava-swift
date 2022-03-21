//
//  RSKochavaDestination.swift
//  RudderKochava
//
//  Created by Pallab Maiti on 21/03/22.
//

import Foundation
import RudderStack
import KochavaTracker
import KochavaAdNetwork

class RSKochavaDestination: RSDestinationPlugin {
    let type = PluginType.destination
    let key = "Firebase"
    var client: RSClient?
    var controller = RSController()
    
    func update(serverConfig: RSServerConfig, type: UpdateType) {
        guard type == .initial else { return }
        if let destination = serverConfig.getDestination(by: key), let config = destination.config?.dictionaryValue {
            if let appGUID = config["apiKey"] as? String {
                if let appTrackingTransparency = config["appTrackingTransparency"] as? Bool {
                    KVATracker.shared.appTrackingTransparency.enabledBool = appTrackingTransparency
                }
                if let skAdNetwork = config["skAdNetwork"] as? Bool, skAdNetwork {
                    KVAAdNetworkProduct.shared.register()
                }
                KVATracker.shared.start(withAppGUIDString: appGUID)
                KVALog.shared.level = getLogLevel(rsLogLevel: client?.configuration.logLevel ?? .none)
            }
        }
    }
    
    func track(message: TrackMessage) -> TrackMessage? {
        var kochavaEvent: KVAEvent?
        if let eventType = getKochavaECommerceEventType(from: message.event) {
            kochavaEvent = KVAEvent.init(type: eventType)
            if let properties = message.properties {
                insertECommerceData(params: &kochavaEvent, properties: properties)
                insertECommerceProductData(params: &kochavaEvent, properties: properties)
            }
        } else {
            kochavaEvent = KVAEvent(customWithNameString: message.event)
        }
        if let properties = message.properties {
            insertCustomPropertiesData(event: &kochavaEvent, properties: properties)
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

// MARK: - Support methods

extension RSKochavaDestination {
    var TRACK_RESERVED_KEYWORDS: [String] {
        return ["product_id", "name", "currency", "quantity", "value", "revenue", "total", "query", "products"]
    }
    
    func getKochavaECommerceEventType(from rudderEvent: String) -> KVAEventType? {
        switch rudderEvent {
        case RSECommerceConstants.ECommProductAdded: return KVAEventType.addToCart
        case RSECommerceConstants.ECommProductAddedToWishList: return KVAEventType.addToWishList
        case RSECommerceConstants.ECommCheckoutStarted: return KVAEventType.checkoutStart
        case RSECommerceConstants.ECommOrderCompleted: return KVAEventType.purchase
        case RSECommerceConstants.ECommProductsSearched: return KVAEventType.search
        case RSECommerceConstants.ECommProductReviewed: return KVAEventType.rating
        case RSECommerceConstants.ECommProductViewed: return KVAEventType.view
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
    
    func insertECommerceData(params: inout KVAEvent?, properties: [String: Any]) {
        if let revenue = properties["revenue"] {
            params?.priceDoubleNumber = Double("\(revenue)") as NSNumber?
        } else if let value = properties["value"] {
            params?.priceDoubleNumber = Double("\(value)") as NSNumber?
        } else if let total = properties["total"] {
            params?.priceDoubleNumber = Double("\(total)") as NSNumber?
        }
        
        if let quantity = properties["quantity"] {
            params?.quantityDoubleNumber = Double("\(quantity)") as NSNumber?
        }
        
        if let currency = properties["currency"] {
            params?.currencyString = "\(currency)"
        }
    }
    
    func insertECommerceProductData(params: inout KVAEvent?, properties: [String: Any]) {
        var nameList: [String]?
        var productIdList: [String]?
        
        if let products = properties["products"] as? [[String: Any]] {
            nameList = products.compactMap { dict in
                return dict["name"] as? String
            }
            productIdList = products.compactMap { dict in
                return dict["product_id"] as? String
            }
        } else {
            if let name = properties["name"] as? String {
                nameList?.append(name)
            }
            if let productId = properties["product_id"] as? String {
                productIdList?.append(productId)
            }
        }
        if let nameList = nameList, let names = getJSONString(list: nameList) {
            params?.nameString = names
        }
        if let productIdList = productIdList, let ids = getJSONString(list: productIdList) {
            params?.contentIdString = ids
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
    
    func insertCustomPropertiesData(event: inout KVAEvent?, properties: [String: Any]) {
        var params: [String: Any]?
        for (key, value) in properties {
            if TRACK_RESERVED_KEYWORDS.contains(key) {
                continue
            }
            switch value {
            case let v as String:
                params?[key] = v
            case let v as Int:
                params?[key] = Double(v)
            case let v as Double:
                params?[key] = v
            default:
                params?[key] = "\(value)"
            }
        }
        event?.infoDictionary = params
    }
}

@objc
public class RudderKochavaDestination: RudderDestination {
    
    public override init() {
        super.init()
        plugin = RSKochavaDestination()
    }
    
}
