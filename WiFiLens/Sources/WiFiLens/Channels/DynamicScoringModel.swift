import Foundation

/// Dynamic channel scoring model that predicts future channel quality
/// based on how user actions (following recommendations) will change the environment.
///
/// This addresses the feedback loop problem (Issue #3): the algorithm recommends
/// channels based on current occupancy, but users switching to those channels
/// degrades their quality. This model predicts the future state and recommends
/// channels that will REMAIN good after migration.
enum DynamicScoringModel {

    /// Configuration constants
    struct Config {
        /// Number of past scan cycles to consider for migration estimation
        static let historyDepth = 5

        /// Default fraction of users who follow recommendations (0.0 - 1.0)
        /// Used when we don't have historical migration data
        static let defaultMigrationFraction = 0.3

        /// Minimum number of observations before using learned migration rate
        static let minObservationsForLearning = 3

        /// Weight for EMA smoothing of migration rate (lower = more stable)
        static let migrationRateAlpha = 0.25
    }

    // MARK: - State

    /// History of past recommendations per band: (channel, timestamp)
    private static var recommendationHistory: [String: [(channel: Int, timestamp: Date)]] = [:]

    /// Observed migration counts: "band-channel" -> list of AP count changes
    /// Positive = APs moved TO this channel, negative = APs moved AWAY
    private static var observedMigrations: [String: [Int]] = [:]

    /// Learned migration rate per band: fraction of users who follow recommendations
    /// Key is band ("24", "5", "6")
    private static var learnedMigrationRate: [String: Double] = [:]

    // MARK: - Public API

    /// Predict future channel quality and select optimal recommendations.
    ///
    /// - Parameters:
    ///   - channels: Current channel qualities with RF scores
    ///   - currentChannel: The channel the user is currently connected to
    ///   - supportedBands: Bands the device supports
    /// - Returns: Channels with `isRecommended` flags set based on predicted future quality
    static func predictAndRecommend(
        channels: [ChannelQuality],
        currentChannel: Int?,
        supportedBands: Set<String>
    ) -> [ChannelQuality] {
        // 1. Record current state for future migration learning
        recordCurrentState(channels: channels)

        // 2. Predict future AP counts for each channel
        let predicted = channels.map { channel -> PredictedChannel in
            let predictedApCount = predictApCount(for: channel)
            let predictedScore = computePredictedScore(
                currentChannel: channel,
                predictedApCount: predictedApCount
            )
            return PredictedChannel(
                original: channel,
                predictedApCount: predictedApCount,
                predictedScore: predictedScore
            )
        }

        // 3. Select top-2 per band based on predicted scores (≥ 70 threshold)
        var result = channels
        for band in supportedBands {
            let bandPredicted = predicted.filter { $0.original.band == band }
            let eligible = bandPredicted
                .filter { $0.predictedScore >= 70 }
                .sorted { $0.predictedScore > $1.predictedScore }
                .prefix(2)

            let recIDs = Set(eligible.map(\.original.id))
            for i in result.indices {
                if result[i].band == band {
                    result[i].isRecommended = recIDs.contains(result[i].id)
                }
            }
        }

        // 4. Update recommendation history
        updateRecommendationHistory(channels: result)

        return result
    }

    /// Learn from observed migration patterns after a new scan.
    /// Call this at the START of each scan cycle with the previous scan's results.
    static func learnFromObservations(currentChannels: [ChannelQuality]) {
        for channel in currentChannels {
            let key = "\(channel.band)-\(channel.channel)"
            guard var history = observedMigrations[key], !history.isEmpty else { continue }

            // Compare with last known recommendation
            if let lastRec = recommendationHistory[channel.band]?.last,
               lastRec.channel == channel.channel {
                // This channel was recommended last scan
                // The AP count change indicates migration
                let apChange = channel.apCount - (history.last ?? 0)
                if apChange > 0 {
                    // APs migrated to this channel
                    history.append(apChange)
                    observedMigrations[key] = history
                }
            }
        }

        // Update learned migration rates per band
        for band in ["24", "5", "6"] {
            updateMigrationRate(for: band)
        }
    }

    /// Reset all state (for testing or when starting a new session)
    static func reset() {
        recommendationHistory.removeAll()
        observedMigrations.removeAll()
        learnedMigrationRate.removeAll()
    }

    // MARK: - Prediction

    private struct PredictedChannel {
        let original: ChannelQuality
        let predictedApCount: Int
        let predictedScore: Int
    }

    /// Predict the future AP count for a channel based on:
    /// 1. Current AP count
    /// 2. Whether this channel was recently recommended (migration pressure)
    /// 3. Historical migration patterns
    private static func predictApCount(for channel: ChannelQuality) -> Int {
        let currentApCount = channel.apCount

        // Check if this channel was recently recommended
        let wasRecentlyRecommended = wasRecommendedInHistory(
            channel: channel.channel,
            band: channel.band,
            withinCycles: 2
        )

        guard wasRecentlyRecommended else {
            // Not recently recommended → no migration pressure
            return currentApCount
        }

        // Estimate migration based on learned rate or default
        let migrationFraction = learnedMigrationRate[channel.band] ?? Config.defaultMigrationFraction

        // Estimate how many APs might migrate
        // Conservative: assume migration = fraction * (total visible APs in band)
        // This is an upper bound - we don't know exact user count
        let totalBandAPs = countTotalAPs(in: channel.band)
        let estimatedMigrations = Int(Double(totalBandAPs) * migrationFraction * 0.1)  // 10% of total as upper bound

        return currentApCount + estimatedMigrations
    }

    /// Compute predicted score based on predicted AP count.
    /// Uses the same interference model as ChannelQualityCalculator but with predicted counts.
    private static func computePredictedScore(
        currentChannel: ChannelQuality,
        predictedApCount: Int
    ) -> Int {
        // Simple linear interpolation: score decreases with AP count
        // This is a simplified model - the real interference is non-linear
        let apPenalty = predictedApCount * 8  // Each AP costs ~8 points
        let currentScore = currentChannel.qualityScore

        // Blend current score with predicted degradation
        // If predicted AP count is close to current, score stays similar
        // If predicted AP count is much higher, score drops significantly
        let apDifference = predictedApCount - currentChannel.apCount
        let degradation = apDifference * 8

        return max(0, min(100, currentScore - degradation))
    }

    // MARK: - History Management

    private static func recordCurrentState(channels: [ChannelQuality]) {
        for channel in channels {
            let key = "\(channel.band)-\(channel.channel)"
            observedMigrations[key, default: []].append(channel.apCount)
        }
    }

    private static func updateRecommendationHistory(channels: [ChannelQuality]) {
        for channel in channels where channel.isRecommended {
            recommendationHistory[channel.band, default: []].append(
                (channel: channel.channel, timestamp: Date())
            )
        }
    }

    private static func wasRecommendedInHistory(
        channel: Int,
        band: String,
        withinCycles: Int
    ) -> Bool {
        guard let history = recommendationHistory[band] else { return false }
        let recentEntries = history.suffix(withinCycles)
        return recentEntries.contains { $0.channel == channel }
    }

    private static func countTotalAPs(in band: String) -> Int {
        // This is a placeholder - in real implementation, we'd track total APs per band
        // For now, use a reasonable estimate based on typical environments
        return 10  // Assume ~10 APs visible per band
    }

    // MARK: - Learning

    private static func updateMigrationRate(for band: String) {
        // Collect migration observations for recommended channels in this band
        guard let history = recommendationHistory[band] else { return }

        var migrationRates: [Double] = []
        for entry in history {
            let key = "\(band)-\(entry.channel)"
            guard let observations = observedMigrations[key],
                  observations.count >= 2 else { continue }

            // Compare first and last observation to see if AP count increased
            let initialAPs = observations.first ?? 0
            let finalAPs = observations.last ?? 0
            if finalAPs > initialAPs {
                let rate = Double(finalAPs - initialAPs) / Double(max(1, initialAPs))
                migrationRates.append(rate)
            }
        }

        guard !migrationRates.isEmpty else { return }

        let avgRate = migrationRates.reduce(0, +) / Double(migrationRates.count)
        let smoothedRate = Config.migrationRateAlpha * avgRate +
            (1 - Config.migrationRateAlpha) * (learnedMigrationRate[band] ?? Config.defaultMigrationFraction)

        learnedMigrationRate[band] = smoothedRate
    }
}
