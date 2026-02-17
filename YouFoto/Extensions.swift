import Photos

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

