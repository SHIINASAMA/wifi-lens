import Foundation

/// Exact port of `series.py` channel span calculation logic.
enum ChannelSpanCalculator {

    /// Convert MHz channel width into half-span measured in channel number steps.
    /// Channel numbers are spaced 5 MHz apart. A 20 MHz channel covers ~4 steps,
    /// so half-span is 2; 40 MHz → 4; 80 → 8; 160 → 16.
    static func channelHalfSpan(for widthMHz: Int) -> Int {
        let totalSteps = Int(round(Double(widthMHz) / 5.0))
        return max(1, totalSteps / 2)
    }

    /// Calculate the actual channel block (left, right) for a primary channel + width + band.
    /// WiFi channels occupy predefined blocks, especially for wider channels.
    static func channelBlock(
        primaryChannel: Int,
        widthMHz: Int,
        band: ChannelBand,
        spanDirection: SpanDirection?
    ) -> (left: Int, right: Int) {
        if widthMHz == 20 {
            return (primaryChannel - 2, primaryChannel + 2)
        }

        if band == .band24GHz {
            if widthMHz == 40 {
                if spanDirection == .upper {
                    return (primaryChannel - 2, primaryChannel + 6)
                } else if spanDirection == .lower {
                    return (primaryChannel - 6, primaryChannel + 2)
                } else {
                    // Default: heuristic based on primary channel position
                    if primaryChannel <= 7 {
                        return (primaryChannel - 2, primaryChannel + 6)
                    } else {
                        return (primaryChannel - 6, primaryChannel + 2)
                    }
                }
            }
        }

        if band == .band5GHz {
            if widthMHz == 40 {
                switch primaryChannel {
                case 36...40:  return (34, 42)
                case 44...48:  return (42, 50)
                case 52...56:  return (50, 58)
                case 60...64:  return (58, 66)
                case 100...104: return (98, 106)
                case 108...112: return (106, 114)
                case 116...120: return (114, 122)
                case 124...128: return (122, 130)
                case 132...136: return (130, 138)
                case 140...144: return (138, 146)
                case 149...153: return (147, 155)
                case 157...161: return (155, 163)
                case 165...169: return (163, 171)
                case 173...177: return (171, 179)
                default: break
                }
            } else if widthMHz == 80 {
                switch primaryChannel {
                case 36...48:   return (34, 50)
                case 52...64:   return (50, 66)
                case 100...112: return (98, 114)
                case 116...128: return (114, 130)
                case 132...144: return (130, 146)
                case 149...161: return (147, 163)
                case 165...177: return (163, 179)
                default: break
                }
            } else if widthMHz == 160 {
                switch primaryChannel {
                case 36...64:   return (34, 66)
                case 100...128: return (98, 130)
                // No 160 MHz block between 132-144
                case 149...177: return (147, 179)
                default: break
                }
            }
        }

        // Fallback for 6 GHz and any unmatched cases
        let half = channelHalfSpan(for: widthMHz)
        return (primaryChannel - half, primaryChannel + half)
    }

    /// Convert an array of WiFiNetwork to ChartSeriesData suitable for Swift Charts.
    /// Malformed entries are silently skipped (defensive, matches Python behavior).
    static func toSeriesData(
        _ networks: [WiFiNetwork],
        colorHasher: SSIDColorHasher
    ) -> [ChartSeriesData] {
        var series: [ChartSeriesData] = []
        for (index, nw) in networks.enumerated() {
            let band = nw.channel.band
            let reportedChannel = nw.channel.channelNumber
            let widthMHz = nw.channel.channelWidthMHz
            let spanDir = nw.channel.spanDirection

            let (left, right) = channelBlock(
                primaryChannel: reportedChannel,
                widthMHz: widthMHz,
                band: band,
                spanDirection: spanDir
            )

            let apex = Double(left + right) / 2.0

            // Guarantee unique IDs per scan, even when CoreWLAN returns duplicate BSSID/channel entries
            let baseID = "\(nw.bssid)-\(reportedChannel)-\(band.rawValue)"
            let uniqueID = "\(baseID)-\(index)"

            series.append(ChartSeriesData(
                id: uniqueID,
                ssid: nw.ssid ?? "n/a",
                bssid: nw.bssid,
                channel: reportedChannel,
                left: left,
                apex: apex,
                right: right,
                rssi: nw.rssi,
                color: colorHasher.color(for: nw.ssid)
            ))
        }
        return series
    }
}
