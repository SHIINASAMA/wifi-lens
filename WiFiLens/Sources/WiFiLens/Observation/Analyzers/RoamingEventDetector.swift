import Foundation

enum RoamingEventDetector {
    static func detect(
        previous: WiFiCurrentStatus?,
        current: WiFiCurrentStatus
    ) -> [WiFiObservationEvent] {
        guard let previous else { return [] }
        var events: [WiFiObservationEvent] = []

        if let prevBSSID = previous.bssid, let curBSSID = current.bssid,
           prevBSSID != curBSSID {
            events.append(WiFiObservationEvent(
                type: .bssidChange(from: prevBSSID, to: curBSSID)
            ))
        }

        if previous.isConnected && !current.isConnected {
            events.append(WiFiObservationEvent(type: .disconnection))
        }

        if !previous.isConnected && current.isConnected {
            events.append(WiFiObservationEvent(type: .reconnection))
        }

        if let prevRSSI = previous.rssi, let curRSSI = current.rssi,
           prevRSSI - curRSSI > 20 {
            events.append(WiFiObservationEvent(
                type: .signalDrop(from: prevRSSI, to: curRSSI)
            ))
        }

        if let prevCh = previous.channel, let curCh = current.channel,
           prevCh != curCh {
            events.append(WiFiObservationEvent(
                type: .channelChange(from: prevCh, to: curCh)
            ))
        }

        return events
    }
}
